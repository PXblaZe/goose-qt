# ctest's goose_qt_installed: installs the build into a scratch prefix, then runs a program that
# imports goose-qt from there, with the JIT and as a native build, with no library path set.
# Arguments: -DBUILD_DIR -DPREFIX -DPKG (the package's directory under the prefix) -DGOOSE -DCONFIG
file(REMOVE_RECURSE "${PREFIX}")
# By component, so the install writes install_manifest_Unspecified.txt: install_manifest.txt
# belongs to the user's own install, which after `sudo cmake --install` only root can write.
execute_process(COMMAND "${CMAKE_COMMAND}" --install "${BUILD_DIR}" --prefix "${PREFIX}" --config "${CONFIG}"
                        --component Unspecified
                RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE out)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "install failed:\n${out}")
endif()
if(IS_ABSOLUTE "${PKG}")
  set(pkg "${PKG}")
else()
  set(pkg "${PREFIX}/${PKG}")
endif()
set(dir "${PREFIX}-check")
file(REMOVE_RECURSE "${dir}")
file(WRITE "${dir}/installed.goose" "import qt from \"${pkg}\";

fn main() {
    if !qt::init(qt::APP_WIDGETS) { print(\"Qt did not start: \", qt::last_error_message()); exit(1); }
    let label = qt::QLabel(\"installed\");
    if label.prop<u8[]>(\"text\") != \"installed\" { print(\"property read wrong\"); exit(1); }
    print(\"goose-qt from the install prefix: ok (qtc \", qt::version(), \", Qt \", qt::qt_version(), \")\");
    qt::shutdown();
}
")
set(envs --unset=LD_LIBRARY_PATH --unset=DYLD_LIBRARY_PATH QT_QPA_PLATFORM=offscreen QT_LOGGING_RULES=*=false)
execute_process(COMMAND "${CMAKE_COMMAND}" -E env ${envs} "${GOOSE}" "${dir}/installed.goose"
                WORKING_DIRECTORY "${dir}" RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE out)
if(NOT rc EQUAL 0 OR NOT out MATCHES "from the install prefix: ok")
  message(FATAL_ERROR "the JIT run of a program importing the installed goose-qt failed:\n${out}")
endif()
message(STATUS "jit: ${out}")
execute_process(COMMAND "${CMAKE_COMMAND}" -E env ${envs} "${GOOSE}" build "${dir}/installed.goose" -o "${dir}/installed"
                WORKING_DIRECTORY "${dir}" RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE out)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "building a program against the installed goose-qt failed:\n${out}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" -E env ${envs} "${dir}/installed"
                WORKING_DIRECTORY "${dir}" RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE out)
if(NOT rc EQUAL 0 OR NOT out MATCHES "from the install prefix: ok")
  message(FATAL_ERROR "the native program importing the installed goose-qt failed:\n${out}")
endif()
message(STATUS "native: ${out}")
