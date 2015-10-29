/*
Copyright 2014 The Kubernetes Authors All rights reserved.

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

package flag

import (
	"fmt"
	"strconv"
)

// Tristate is a boolean flag compatible with flags and pflags that keeps track of whether it had a value supplied or not.
// Beware!  If you use this type, you must actually specify --flag-name=true, you cannot leave it as --flag-name and still have
// the value set
type Tristate struct {
	// If Set has been invoked this value is true
	provided bool
	// The exact value provided on the flag
	value bool
}

func (f *Tristate) Default(value bool) {
	f.value = value
}

func (f Tristate) String() string {
	return fmt.Sprintf("%t", f.value)
}

func (f Tristate) Value() bool {
	return f.value
}

func (f *Tristate) Set(value string) error {
	boolVal, err := strconv.ParseBool(value)
	if err != nil {
		return err
	}

	f.value = boolVal
	f.provided = true

	return nil
}

func (f Tristate) Provided() bool {
	return f.provided
}

func (f *Tristate) Type() string {
	return "bool"
}
