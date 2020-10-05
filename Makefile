SHELL := bash # the shell used internally by "make"

# used inside the included makefiles
BUILD_SYSTEM_DIR := vendor/nimbus-build-system

# we don't want an error here, so we can handle things later, in the ".DEFAULT" target
-include $(BUILD_SYSTEM_DIR)/makefiles/variables.mk

.PHONY: \
	all \
	deps \
	update \
	test \
	nescience \
	clean

ifeq ($(NIM_PARAMS),)
# "variables.mk" was not included, so we update the submodules.
GIT_SUBMODULE_UPDATE := git submodule update --init --recursive
.DEFAULT:
	+@ echo -e "Git submodules not found. Running '$(GIT_SUBMODULE_UPDATE)'.\n"; \
		$(GIT_SUBMODULE_UPDATE) && \
		echo
# Now that the included *.mk files appeared, and are newer than this file, Make will restart itself:
# https://www.gnu.org/software/make/manual/make.html#Remaking-Makefiles
#
# After restarting, it will execute its original goal, so we don't have to start a child Make here
# with "$(MAKE) $(MAKECMDGOALS)". Isn't hidden control flow great?

else # "variables.mk" was included. Business as usual until the end of this file.

# default target, because it's the first one that doesn't start with '.'
all: | nescience

# must be included after the default target
-include $(BUILD_SYSTEM_DIR)/makefiles/targets.mk

# add a default Nim compiler argument
NIM_PARAMS += --outdir:./bin -d:debug

RELEASE_PARAMS += -d:danger # TODO Arraymancer performance

deps: | deps-common nescience.nims
	# Have custom deps? Add them above.

update: | update-common
	rm -rf nescience.nims && \
		$(MAKE) nescience.nims $(HANDLE_OUTPUT)

test: | build deps
	$(ENV_SCRIPT) nim test $(NIM_PARAMS) nescience.nims

# building Nim programs
nescience: | build deps
	echo -e $(BUILD_MSG) "$@" && \
		$(ENV_SCRIPT) nim c $(NIM_PARAMS) "$@.nim"

# symlink
nescience.nims:
	ln -s nescience.nimble $@

clean: | clean-common
	rm -rf bin/*

endif # "variables.mk" was not included