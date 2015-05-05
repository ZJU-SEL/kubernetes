/*
Copyright 2015 Google Inc. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package e2e

import (
	"fmt"
	"path"

	"github.com/GoogleCloudPlatform/kubernetes/pkg/api"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/api/latest"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/client"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/util"

	. "github.com/onsi/ginkgo"
)

var _ = Describe("HostDir", func() {
	var (
		c         *client.Client
		podClient client.PodInterface
	)

	BeforeEach(func() {
		var err error
		c, err = loadClient()
		expectNoError(err)

		podClient = c.Pods(api.NamespaceDefault)
	})

	It("should detect writing operation in the container", func() {
		volumePath := "/home"
		//hostfilePath := path.Join(volumePath, "hostdir-test-file") // hostfilePath:/home/vcap/hostdir-test-file

		source := &api.HostPathVolumeSource{
			Path: "/home", //container
		}
		containerfilePath := path.Join(source.Path, "hostdir-test-file") // containerfilePath: /home/hostdir-test-file

		pod := testPodWithHostVolume(volumePath, source)
		pod.Spec.Containers[0].Args = []string{
			fmt.Sprintf("--write_new_file=%v", containerfilePath), //container[0]
		}
		pod.Spec.Containers[1].Args = []string{
			fmt.Sprintf("--file_content=%v", containerfilePath), //container[1]
		}
		testContainerOutput("hostdir r/w", c, pod, 1, []string{
			"content of file \"/home/hostdir-test-file\": hostdir-mount-tester new file",
		})
	})

})

const containerName1 = "test-container-1"
const containerName2 = "test-container-2"
const hostdirvolumeName = "test-volume"

func testPodWithHostVolume(path string, source *api.HostPathVolumeSource) *api.Pod {
	podName := "pod-" + string(util.NewUUID())

	return &api.Pod{
		TypeMeta: api.TypeMeta{
			Kind:       "Pod",
			APIVersion: latest.Version,
		},
		ObjectMeta: api.ObjectMeta{
			Name: podName,
		},
		Spec: api.PodSpec{
			Containers: []api.Container{
				{
					Name:  containerName1,
					Image: "dalanlan/host-dir-mounttest:0.1",
					VolumeMounts: []api.VolumeMount{
						{
							Name:      hostdirvolumeName,
							MountPath: path,
						},
					},
				},
				{
					Name:  containerName2,
					Image: "dalanlan/host-dir-mounttest:0.1",
					VolumeMounts: []api.VolumeMount{
						{
							Name:      hostdirvolumeName,
							MountPath: path,
						},
					},
				},
			},
			Volumes: []api.Volume{
				{
					Name: hostdirvolumeName,
					VolumeSource: api.VolumeSource{
						HostPath: source,
					},
				},
			},
		},
	}
}
