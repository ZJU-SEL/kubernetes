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

package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"time"
)

var (
	fileModePath        = ""
	readFileContentPath = ""
	writeNewFilePath    = ""
)

func init() {
	flag.StringVar(&fileModePath, "file_mode", "", "Path to print the filemode of")
	flag.StringVar(&readFileContentPath, "file_content", "", "Path to read the file content from")
	flag.StringVar(&writeNewFilePath, "write_new_file", "", "Path to write to")
}

// This program performs some tests on the filesystem as dictated by the
// flags passed by the user.
func main() {
	flag.Parse()

	var (
		err  error
		errs = []error{}
	)

	err = WriteNewFile(writeNewFilePath)
	if err != nil {
		errs = append(errs, err)
	}

	err = fileMode(fileModePath)
	if err != nil {
		errs = append(errs, err)
	}

	err = readFileContent(readFileContentPath)
	if err != nil {
		errs = append(errs, err)
	}

	if len(errs) != 0 {
		os.Exit(1)
	}

	os.Exit(0)
}

func fileMode(path string) error {
	if path == "" {
		return nil
	}

	fileinfo, err := os.Lstat(path)
	if err != nil {
		fmt.Printf("error from Lstat(%q): %v\n", path, err)
		return err
	}

	fmt.Printf("mode of file %q: %v\n", path, fileinfo.Mode())
	return nil
}

func readFileContent(path string) error {
	if path == "" {
		return nil
	}
	var (
		contentBytes []byte
		err          error
	)
	start := time.Now()
	for time.Now().Sub(start) < (300 * time.Second) {

		contentBytes, err = ioutil.ReadFile(path)
		if len(string(contentBytes)) != 0 {
			break
		}
		if err != nil {
			fmt.Printf("error reading file content for %q: %v\n", path, err)
			time.Sleep(5 * time.Second)
			continue
		}
	}

	fmt.Printf("content of file %q: %v\n", path, string(contentBytes))

	return nil
}

func WriteNewFile(path string) error {
	if path == "" {
		return nil
	}

	content := "hostdir-mount-tester new file\n"
	err := ioutil.WriteFile(path, []byte(content), 0644)
	if err != nil {
		fmt.Printf("error writing new file %q: %v\n", path, err)
		return err
	}

	return nil
}
