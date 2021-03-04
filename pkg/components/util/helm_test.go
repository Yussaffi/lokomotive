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

package util_test

import (
	"testing"

	"github.com/kinvolk/lokomotive/pkg/components"
	"github.com/kinvolk/lokomotive/pkg/components/util"
)

func TestRenderChartBadValues(t *testing.T) {
	c := "cert-manager"
	values := "malformed\t"

	helmChart, err := components.Chart(c)
	if err != nil {
		t.Fatalf("Loading chart from assets should succeed, got: %v", err)
	}

	if _, err := util.RenderChart(helmChart, c, c, values); err == nil {
		t.Fatalf("Rendering chart with malformed values should fail")
	}
}
