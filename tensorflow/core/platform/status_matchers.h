/* Copyright 2021 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/
#ifndef TENSORFLOW_CORE_PLATFORM_STATUS_MATCHERS_H_
#define TENSORFLOW_CORE_PLATFORM_STATUS_MATCHERS_H_

#include "xla/tsl/platform/status_matchers.h"

namespace tensorflow {
namespace testing {
// NOLINTBEGIN(misc-unused-using-decls)
using tsl::testing::IsOk;
using tsl::testing::IsOkAndHolds;
using tsl::testing::StatusIs;
// NOLINTEND(misc-unused-using-decls)
}  // namespace testing
}  // namespace tensorflow

#endif  // TENSORFLOW_CORE_PLATFORM_STATUS_MATCHERS_H_
