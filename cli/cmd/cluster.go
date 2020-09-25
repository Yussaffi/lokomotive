// Copyright 2020 The Lokomotive Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package cmd

import (
	"fmt"

	"github.com/mitchellh/go-homedir"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/chart"
	"sigs.k8s.io/yaml"

	"github.com/kinvolk/lokomotive/pkg/backend"
	"github.com/kinvolk/lokomotive/pkg/backend/local"
	"github.com/kinvolk/lokomotive/pkg/components/util"
	"github.com/kinvolk/lokomotive/pkg/config"
	"github.com/kinvolk/lokomotive/pkg/platform"
	"github.com/kinvolk/lokomotive/pkg/terraform"
)

var clusterCmd = &cobra.Command{
	Use:   "cluster",
	Short: "Manage a cluster",
}

func init() {
	RootCmd.AddCommand(clusterCmd)
}

// initialize does common initialization actions between cluster operations
// and returns created objects to the caller for further use.
func initialize(contextLogger *log.Entry) (*terraform.Executor, platform.Platform, *config.Config, string) {
	lokoConfig, diags := getLokoConfig()
	if diags.HasErrors() {
		contextLogger.Fatal(diags)
	}

	p, diags := getConfiguredPlatform(lokoConfig, true)
	if diags.HasErrors() {
		for _, diagnostic := range diags {
			contextLogger.Error(diagnostic.Error())
		}

		contextLogger.Fatal("Errors found while loading cluster configuration")
	}

	// Get the configured backend for the cluster. Backend types currently supported: local, s3.
	b, diags := getConfiguredBackend(lokoConfig)
	if diags.HasErrors() {
		for _, diagnostic := range diags {
			contextLogger.Error(diagnostic.Error())
		}

		contextLogger.Fatal("Errors found while loading cluster configuration")
	}

	// Use a local backend if no backend is configured.
	if b == nil {
		b = local.NewLocalBackend()
	}

	assetDir, err := homedir.Expand(p.Meta().AssetDir)
	if err != nil {
		contextLogger.Fatalf("Error expanding path: %v", err)
	}

	// Validate backend configuration.
	if err = b.Validate(); err != nil {
		contextLogger.Fatalf("Failed to validate backend configuration: %v", err)
	}

	ex := initializeTerraform(contextLogger, p, b)

	return ex, p, lokoConfig, assetDir
}

// initializeTerraform initialized Terraform directory using given backend and platform
// and returns configured executor.
func initializeTerraform(contextLogger *log.Entry, p platform.Platform, b backend.Backend) *terraform.Executor {
	assetDir, err := homedir.Expand(p.Meta().AssetDir)
	if err != nil {
		contextLogger.Fatalf("Error expanding path: %v", err)
	}

	// Render backend configuration.
	renderedBackend, err := b.Render()
	if err != nil {
		contextLogger.Fatalf("Failed to render backend configuration file: %v", err)
	}

	// Configure Terraform directory, module and backend.
	if err := terraform.Configure(assetDir, renderedBackend); err != nil {
		contextLogger.Fatalf("Failed to configure Terraform : %v", err)
	}

	conf := terraform.Config{
		WorkingDir: terraform.GetTerraformRootDir(assetDir),
		Verbose:    verbose,
	}

	ex, err := terraform.NewExecutor(conf)
	if err != nil {
		contextLogger.Fatalf("Failed to create Terraform executor: %v", err)
	}

	if err := p.Initialize(ex); err != nil {
		contextLogger.Fatalf("Failed to initialize Platform: %v", err)
	}

	if err := ex.Init(); err != nil {
		contextLogger.Fatalf("Failed to initialize Terraform: %v", err)
	}

	return ex
}

// clusterExists determines if cluster has already been created by getting all
// outputs from the Terraform. If there is any output defined, it means 'terraform apply'
// run at least once.
func clusterExists(contextLogger *log.Entry, ex *terraform.Executor) bool {
	o := map[string]interface{}{}

	if err := ex.Output("", &o); err != nil {
		contextLogger.Fatalf("Failed to check if cluster exists: %v", err)
	}

	return len(o) != 0
}

type controlplaneUpdater struct {
	kubeconfig    []byte
	assetDir      string
	contextLogger log.Entry
	ex            terraform.Executor
}

func (c controlplaneUpdater) getControlplaneChart(name string) (*chart.Chart, error) {
	chart, err := platform.ControlPlaneChart(name)
	if err != nil {
		return nil, fmt.Errorf("loading chart from assets failed: %w", err)
	}

	if err := chart.Validate(); err != nil {
		return nil, fmt.Errorf("chart is invalid: %w", err)
	}

	return chart, nil
}

func (c controlplaneUpdater) getControlplaneValues(name string) (map[string]interface{}, error) {
	valuesRaw := ""
	if err := c.ex.Output(fmt.Sprintf("%s_values", name), &valuesRaw); err != nil {
		return nil, fmt.Errorf("failed to get controlplane component values.yaml from Terraform: %w", err)
	}

	values := map[string]interface{}{}
	if err := yaml.Unmarshal([]byte(valuesRaw), &values); err != nil {
		return nil, fmt.Errorf("failed to parse values.yaml for controlplane component: %w", err)
	}

	return values, nil
}

func (c controlplaneUpdater) upgradeComponent(component, namespace string) {
	contextLogger := c.contextLogger.WithFields(log.Fields{
		"action":    "controlplane-upgrade",
		"component": component,
	})

	actionConfig, err := util.HelmActionConfig(namespace, c.kubeconfig)
	if err != nil {
		contextLogger.Fatalf("Failed initializing helm: %v", err)
	}

	helmChart, err := c.getControlplaneChart(component)
	if err != nil {
		contextLogger.Fatalf("Loading chart from assets failed: %v", err)
	}

	values, err := c.getControlplaneValues(component)
	if err != nil {
		contextLogger.Fatalf("Failed to get kubernetes values.yaml from Terraform: %v", err)
	}

	exists, err := util.ReleaseExists(*actionConfig, component)
	if err != nil {
		contextLogger.Fatalf("Failed checking if controlplane component is installed: %v", err)
	}

	if !exists {
		fmt.Printf("Controlplane component '%s' is missing, reinstalling...", component)

		install := action.NewInstall(actionConfig)
		install.ReleaseName = component
		install.Namespace = namespace
		install.Atomic = true
		install.CreateNamespace = true

		if _, err := install.Run(helmChart, values); err != nil {
			fmt.Println("Failed!")

			contextLogger.Fatalf("Installing controlplane component failed: %v", err)
		}

		fmt.Println("Done.")
	}

	update := action.NewUpgrade(actionConfig)

	update.Atomic = true

	fmt.Printf("Ensuring controlplane component '%s' is up to date... ", component)

	if _, err := update.Run(component, helmChart, values); err != nil {
		fmt.Println("Failed!")

		contextLogger.Fatalf("Updating chart failed: %v", err)
	}

	fmt.Println("Done.")
}
