#/
# @license Apache-2.0
#
# Copyright (c) 2017 The Stdlib Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#/

# VARIABLES #

# On Mac OSX, in order to use `|` and other regular expression operators, we need to use enhanced regular expression syntax (-E); see https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man7/re_format.7.html#//apple_ref/doc/man/7/re_format.

ifeq ($(OS), Darwin)
	find_kernel_prefix := -E
else
	find_kernel_prefix :=
endif

# Define command-line flags for finding test directories for instrumented source code:
FIND_ISTANBUL_TEST_DIRS_FLAGS ?= \
	-type d \
	-name "$(TESTS_FOLDER)" \
	-regex "$(TESTS_FILTER)"

ifneq ($(OS), Darwin)
	FIND_ISTANBUL_TEST_DIRS_FLAGS := -regextype posix-extended $(FIND_ISTANBUL_TEST_DIRS_FLAGS)
endif

# Define the executable for generating a coverage report name:
COVERAGE_REPORT_NAME ?= $(TOOLS_DIR)/test-cov/scripts/istanbul_coverage_report_name

# Define the path to the Istanbul executable.
#
# ## Notes
#
# -   To install Istanbul:
#
#     ```bash
#     $ npm install istanbul@0.4.5
#     ```
#
# [1]: https://github.com/gotwarlost/istanbul
ISTANBUL ?= $(BIN_DIR)/istanbul

# Define which files and directories to exclude from coverage instrumentation:
ISTANBUL_EXCLUDES_FLAGS ?= \
	--no-default-excludes \
	-x 'node_modules/**' \
	-x 'reports/**' \
	-x 'tmp/**' \
	-x 'deps/**' \
	-x 'dist/**' \
	-x "**/$(SRC_FOLDER)/**" \
	-x "**/$(TESTS_FOLDER)/**" \
	-x "**/$(EXAMPLES_FOLDER)/**" \
	-x "**/$(BENCHMARKS_FOLDER)/**" \
	-x "**/$(CONFIG_FOLDER)/**" \
	-x "**/$(DOCUMENTATION_FOLDER)/**"

# Define which files and directories to exclude when syncing the instrumented source code directory:
ISTANBUL_RSYNC_EXCLUDES_FLAGS ?= \
	--ignore-existing \
	--exclude "$(EXAMPLES_FOLDER)/" \
	--exclude "$(BENCHMARKS_FOLDER)/"

# Define the command to instrument source code for code coverage:
ISTANBUL_INSTRUMENT ?= $(ISTANBUL) instrument

# Define the output directory for instrumented source code:
ISTANBUL_INSTRUMENT_OUT ?= $(COVERAGE_INSTRUMENTATION_DIR)/node_modules

# Define the command-line options to be used when instrumenting source code:
ISTANBUL_INSTRUMENT_FLAGS ?= \
	$(ISTANBUL_EXCLUDES_FLAGS) \
	--output $(ISTANBUL_INSTRUMENT_OUT)

# Define the command to generate test coverage:
ISTANBUL_COVER ?= $(ISTANBUL) cover

# Define the type of report Istanbul should produce:
ISTANBUL_COVER_REPORT_FORMAT ?= lcov

# Define the output file path for the HTML report generated by Istanbul:
ISTANBUL_HTML_REPORT ?= $(COVERAGE_DIR)/lcov-report/index.html

# Define the output file path for the JSON report generated by Istanbul:
ISTANBUL_JSON_REPORT ?= $(COVERAGE_DIR)/coverage.json

# Define the command-line options to be used when generating code coverage:
ISTANBUL_COVER_FLAGS ?= \
	$(ISTANBUL_EXCLUDES_FLAGS) \
	--dir $(COVERAGE_DIR) \
	--report $(ISTANBUL_COVER_REPORT_FORMAT)

# Define the command to generate test coverage reports:
ISTANBUL_REPORT ?= $(ISTANBUL) report

# Define the test coverage report format:
ISTANBUL_REPORT_FORMAT ?= lcov

# Define the command-line options to be used when generating a code coverage report:
ISTANBUL_REPORT_FLAGS ?= \
	--root $(COVERAGE_DIR) \
	--dir $(COVERAGE_DIR) \
	--include '**/coverage*.json'

# Define the test runner executable for Istanbul instrumented source code:
ifeq ($(JAVASCRIPT_TEST_RUNNER), tape)
	ISTANBUL_TEST_RUNNER ?= $(NODE) $(TOOLS_PKGS_DIR)/test-cov/tape-istanbul/bin/cli
	ISTANBUL_TEST_RUNNER_FLAGS ?= \
		--dir $(ISTANBUL_INSTRUMENT_OUT) \
		--global '__coverage__'
endif


# FUNCTIONS #

#/
# Macro to retrieve a list of test directories for Istanbul instrumented source code.
#
# @private
#
# @example
# $(call get-istanbul-test-dirs)
#/
get-istanbul-test-dirs = $(shell find $(find_kernel_prefix) $(ISTANBUL_INSTRUMENT_OUT) $(FIND_ISTANBUL_TEST_DIRS_FLAGS))


# RULES #

#/
# Instruments source code.
#
# ## Notes
#
# -   This recipe does the following:
#
#     1.  Instruments all package source files and writes the instrumented files to a specified directory (e.g., a `build` directory).
#     2.  Copies all non-instrumented package files to the instrumentation directory. This is necessary as files such as `*.json` files are not instrumented, and thus, the files are not copied over by Istanbul.
#
#     In short, we need to effectively recreate the project source tree in the instrumentation directory in order for tests to properly run.
#
# @private
#
# @example
# make test-istanbul-instrument
#/
test-istanbul-instrument: $(NODE_MODULES) clean-istanbul-instrument
	$(QUIET) $(MKDIR_RECURSIVE) $(ISTANBUL_INSTRUMENT_OUT)
	$(QUIET) $(ISTANBUL_INSTRUMENT) $(ISTANBUL_INSTRUMENT_FLAGS) $(SRC_DIR)
	$(QUIET) $(RSYNC_RECURSIVE) \
		$(ISTANBUL_RSYNC_EXCLUDES_FLAGS) \
		$(SRC_DIR)/ \
		$(ISTANBUL_INSTRUMENT_OUT)

.PHONY: test-istanbul-instrument

#/
# Runs unit tests and generates a test coverage report.
#
# ## Notes
#
# -   Raw TAP output is piped to a TAP reporter.
# -   This command is useful when wanting to glob for JavaScript test files (e.g., generate a test coverage report for all JavaScript tests for a particular package).
#
#
# @private
# @param {string} [TESTS_FILTER] - file path pattern (e.g., `.*/blas/base/dasum/.*`)
# @param {*} [FAST_FAIL] - flag indicating whether to stop running tests upon encountering a test failure
#
# @example
# make test-istanbul
#
# @example
# make test-istanbul TESTS_FILTER=".*/blas/base/dasum/.*"
#/
test-istanbul: $(NODE_MODULES) test-istanbul-instrument
	$(QUIET) $(MKDIR_RECURSIVE) $(COVERAGE_DIR)
	$(QUIET) $(MAKE_EXECUTABLE) $(COVERAGE_REPORT_NAME)
	$(QUIET) for dir in $(get-istanbul-test-dirs); do \
		echo ''; \
		echo "Running tests in directory: $$dir"; \
		echo ''; \
		NODE_ENV="$(NODE_ENV_TEST)" \
		NODE_PATH="$(NODE_PATH_TEST)" \
		TEST_MODE=coverage \
		$(ISTANBUL_TEST_RUNNER) \
			$(ISTANBUL_TEST_RUNNER_FLAGS) \
			--output $$($(COVERAGE_REPORT_NAME) $(ISTANBUL_INSTRUMENT_OUT) $$dir $(COVERAGE_DIR)) \
			"$$dir/**/$(TESTS_PATTERN)" \
		| $(TAP_REPORTER) || exit 1; \
	done
	$(QUIET) $(MAKE) -f $(this_file) test-istanbul-report

.PHONY: test-istanbul

#/
# Generates a single test coverage report from one or more JSON coverage files.
#
# @private
#
# @example
# make test-istanbul-report
#/
test-istanbul-report: $(NODE_MODULES)
	$(QUIET) $(ISTANBUL_REPORT) $(ISTANBUL_REPORT_FLAGS) $(ISTANBUL_REPORT_FORMAT)

.PHONY: test-istanbul-report

#/
# Runs unit tests and generates a test coverage report.
#
# ## Notes
#
# -   This recipe implements the "classic" approach for using Istanbul to generate a code coverage report using the `cover` command. For certain situations, this recipe can still be used, but, in general, when using Istanbul, we instrument, backfill package files, and generate a coverage report from the instrumentation directory.
#
# @private
#
# @example
# make test-istanbul-cover
#/
test-istanbul-cover: $(NODE_MODULES)
	$(QUIET) NODE_ENV="$(NODE_ENV_TEST)" \
	NODE_PATH="$(NODE_PATH_TEST)" \
	TEST_MODE=coverage \
	$(ISTANBUL_COVER) $(ISTANBUL_COVER_FLAGS) $(JAVASCRIPT_TEST) -- $(JAVASCRIPT_TEST_FLAGS) $(TESTS)

.PHONY: test-istanbul-cover

#/
# Opens an HTML test coverage report in a local web browser.
#
# @private
#
# @example
# make view-istanbul-report
#/
view-istanbul-report:
	$(QUIET) $(OPEN) $(ISTANBUL_HTML_REPORT)

.PHONY: view-istanbul-report

#/
# Removes instrumented files.
#
# @private
#
# @example
# make clean-istanbul-instrument
#/
clean-istanbul-instrument:
	$(QUIET) $(DELETE) $(DELETE_FLAGS) $(COVERAGE_INSTRUMENTATION_DIR)

.PHONY: clean-istanbul-instrument
