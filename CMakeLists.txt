# goose-qt: builds (when asked) and installs the Goose package, and runs its tests.
#
# goose-qt itself is Goose source that programs import; what it needs built is qtc, the C
# library it loads at run time. This project uses an installed qtc, or builds one from source
# as part of the same build, and installs the package so that programs import it from the
# install prefix and find qtc there without a library path:
#
#   cmake -S goose-qt -B build -DCMAKE_PREFIX_PATH="<qtc prefix>;<Qt prefix>"   # an installed qtc
#   cmake -S goose-qt -B build -DQTC_SOURCE_DIR=path/to/qtc                    # build qtc here too
#   cmake --build build
#   ctest --test-dir build                  # goose-qt's tests, examples and samples (needs goose)
#   cmake --install build --prefix /usr/local
#
# then, in a program:  import qt from "/usr/local/share/goose-qt";
cmake_minimum_required(VERSION 3.21)
project(goose_qt VERSION 1.5.0 DESCRIPTION "Qt 6 for the Goose language, through qtc" LANGUAGES C)   # C: for GNUInstallDirs, and goose builds use it anyway
include(GNUInstallDirs)

set(GOOSE_QT_QTC_MIN 1.2.0)   # api.goose calls the direct entry points (qtc_direct.h) qtc 1.2.0 added

set(QTC_SOURCE_DIR "" CACHE PATH
  "qtc's source directory: build qtc as part of this build (empty: use an installed qtc, else ../qtc)")
option(GOOSE_QT_BUILD_QTC "Build qtc from QTC_SOURCE_DIR even when an installed one is found" OFF)
set(GOOSE_QT_INSTALL_DIR "${CMAKE_INSTALL_DATADIR}/goose-qt" CACHE STRING
  "Where under the install prefix the package goes; programs import it from there")
option(GOOSE_QT_PIN_QTC "Write qtc's installed path into the installed qt.build, so programs need no library path" ON)
option(GOOSE_QT_TESTS "Register goose-qt's tests, examples and samples with ctest (they need goose)" ON)
set(GOOSE_EXECUTABLE "" CACHE FILEPATH "The goose compiler (found on PATH, or from the GOOSE environment variable)")

# ------------------------------------------------------------------ qtc

set(_build_qtc ${GOOSE_QT_BUILD_QTC})
if(NOT _build_qtc)
  find_package(qtc ${GOOSE_QT_QTC_MIN} CONFIG QUIET)
  if(NOT qtc_FOUND)
    if(QTC_SOURCE_DIR STREQUAL "" AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../qtc/CMakeLists.txt")
      set(QTC_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../qtc" CACHE PATH "" FORCE)
    endif()
    if(QTC_SOURCE_DIR STREQUAL "")
      message(FATAL_ERROR
        "goose-qt: no qtc ${GOOSE_QT_QTC_MIN} or later found. Install qtc and pass its prefix in "
        "CMAKE_PREFIX_PATH, or pass -DQTC_SOURCE_DIR=<qtc source> to build it with goose-qt.")
    endif()
    set(_build_qtc ON)
  endif()
endif()

if(_build_qtc)
  get_filename_component(QTC_SOURCE_DIR "${QTC_SOURCE_DIR}" ABSOLUTE)
  if(NOT EXISTS "${QTC_SOURCE_DIR}/CMakeLists.txt" OR NOT EXISTS "${QTC_SOURCE_DIR}/include/qtc.h")
    message(FATAL_ERROR "goose-qt: QTC_SOURCE_DIR (${QTC_SOURCE_DIR}) is not qtc's source directory")
  endif()
  file(STRINGS "${QTC_SOURCE_DIR}/include/qtc.h" _v REGEX "#define QTC_VERSION_STRING")
  string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" _qtc_version "${_v}")
  if(_qtc_version VERSION_LESS GOOSE_QT_QTC_MIN)
    message(FATAL_ERROR "goose-qt: qtc ${_qtc_version} in ${QTC_SOURCE_DIR} is older than ${GOOSE_QT_QTC_MIN}")
  endif()
  # qtc's own tests and examples are not goose-qt's; the user can still turn them on
  if(NOT DEFINED QTC_BUILD_TESTS)
    set(QTC_BUILD_TESTS OFF CACHE BOOL "Build qtc's test suite")
  endif()
  if(NOT DEFINED QTC_BUILD_EXAMPLES)
    set(QTC_BUILD_EXAMPLES OFF CACHE BOOL "Build qtc's C examples")
  endif()
  message(STATUS "goose-qt: building qtc ${_qtc_version} from ${QTC_SOURCE_DIR}")
  add_subdirectory("${QTC_SOURCE_DIR}" qtc)
  set(_qtc qtc)
  set(_qtc_manifest "${QTC_SOURCE_DIR}/manifest/qtc_api.json")
else()
  message(STATUS "goose-qt: using qtc ${qtc_VERSION} from ${qtc_DIR}")
  set(_qtc qtc::qtc)
  get_filename_component(_qtc_prefix "${qtc_DIR}/../../.." ABSOLUTE)
  set(_qtc_manifest "${_qtc_prefix}/${CMAKE_INSTALL_DATADIR}/qtc/qtc_api.json")
  if(NOT EXISTS "${_qtc_manifest}")
    set(_qtc_manifest "${_qtc_prefix}/share/qtc/qtc_api.json")
  endif()
endif()
if(TARGET ${_qtc}_test)
  set(_qtc_test ${_qtc}_test)
elseif(TARGET qtc::qtc_test)
  set(_qtc_test qtc::qtc_test)
else()
  set(_qtc_test "")
endif()

# ------------------------------------------------------------------ goose

if(GOOSE_EXECUTABLE STREQUAL "")
  find_program(_goose NAMES goose HINTS ENV GOOSE)
  if(_goose)
    set(GOOSE_EXECUTABLE "${_goose}" CACHE FILEPATH "" FORCE)
  elseif(DEFINED ENV{GOOSE} AND EXISTS "$ENV{GOOSE}")
    set(GOOSE_EXECUTABLE "$ENV{GOOSE}" CACHE FILEPATH "" FORCE)
  endif()
endif()
if(GOOSE_EXECUTABLE)
  # goose-qt uses const if and type arguments in method calls (Goose from 2026-11-08 on)
  set(_probe "${CMAKE_CURRENT_BINARY_DIR}/goose_probe/probe.goose")
  file(WRITE "${_probe}" "fn pick<T>(x: i64) -> i64 { const if same<T, i64> { return x; } else { return 0; } }\n"
                         "fn main() { let a = 3; if a.pick<i64>() != 3 { exit(1); } }\n")
  execute_process(COMMAND "${GOOSE_EXECUTABLE}" "${_probe}" RESULT_VARIABLE _probe_rc
                  OUTPUT_QUIET ERROR_VARIABLE _probe_err TIMEOUT 120)
  if(_probe_rc EQUAL 0)
    message(STATUS "goose-qt: using goose ${GOOSE_EXECUTABLE}")
  else()
    message(WARNING "goose-qt: ${GOOSE_EXECUTABLE} cannot compile goose-qt (it needs `const if`, in Goose "
                    "from 2026-11-08 on); update Goose. The probe said:\n${_probe_err}")
  endif()
else()
  message(STATUS "goose-qt: no goose found (set GOOSE_EXECUTABLE): installing works, the tests are left out")
endif()

# ------------------------------------------------------------------ the package

set(_pkg_files qt.goose extra.goose api.goose README.md CHANGELOG.md LICENSE)
install(FILES ${_pkg_files} DESTINATION "${GOOSE_QT_INSTALL_DIR}")
install(DIRECTORY include examples test gen DESTINATION "${GOOSE_QT_INSTALL_DIR}" USE_SOURCE_PERMISSIONS
        PATTERN "__pycache__" EXCLUDE PATTERN "*.png" EXCLUDE PATTERN "*.pyc" EXCLUDE)
# the samples import the package as "../..", which holds installed too; their screenshots and
# the docs' go along
install(DIRECTORY samples docs DESTINATION "${GOOSE_QT_INSTALL_DIR}" USE_SOURCE_PERMISSIONS)

# qt.build names the shared libraries goose-qt opens. Installed, it can name them by full path:
# this platform's line gets the path qtc is installed at, the other platforms' lines stay.
if(GOOSE_QT_PIN_QTC)
  if(WIN32)
    set(_plat windows)
  elseif(APPLE)
    set(_plat macos)
  else()
    set(_plat linux)
  endif()
  if(_build_qtc)
    # qtc is installed with goose-qt: its path is known only once the prefix is (at install)
    if(WIN32)
      set(_qtc_path "@PREFIX@/${CMAKE_INSTALL_BINDIR}/$<TARGET_FILE_NAME:${_qtc}>")
      if(_qtc_test)
        set(_qtc_test_path "@PREFIX@/${CMAKE_INSTALL_BINDIR}/$<TARGET_FILE_NAME:${_qtc_test}>")
      endif()
    else()
      set(_qtc_path "@PREFIX@/${CMAKE_INSTALL_LIBDIR}/$<TARGET_SONAME_FILE_NAME:${_qtc}>")
      if(_qtc_test)
        set(_qtc_test_path "@PREFIX@/${CMAKE_INSTALL_LIBDIR}/$<TARGET_SONAME_FILE_NAME:${_qtc_test}>")
      endif()
    endif()
  else()
    if(WIN32)
      set(_qtc_path "$<TARGET_FILE:${_qtc}>")
      if(_qtc_test)
        set(_qtc_test_path "$<TARGET_FILE:${_qtc_test}>")
      endif()
    else()
      set(_qtc_path "$<TARGET_SONAME_FILE:${_qtc}>")
      if(_qtc_test)
        set(_qtc_test_path "$<TARGET_SONAME_FILE:${_qtc_test}>")
      endif()
    endif()
  endif()
  set(_line "dylibs_${_plat} = [\"qtc=${_qtc_path}\"")
  if(_qtc_test)
    string(APPEND _line ", \"qtc_test=${_qtc_test_path}\"")
  endif()
  string(APPEND _line "];   // set when goose-qt was installed")
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/qt.build" _build_src)
  string(REGEX REPLACE "dylibs_${_plat} = \\[[^]]*\\];" "${_line}" _pinned "${_build_src}")
  file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/qt.build.$<CONFIG>" CONTENT "${_pinned}")
  install(CODE "
    set(_dest \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${GOOSE_QT_INSTALL_DIR}/qt.build\")
    if(IS_ABSOLUTE \"${GOOSE_QT_INSTALL_DIR}\")
      set(_dest \"\$ENV{DESTDIR}${GOOSE_QT_INSTALL_DIR}/qt.build\")
    endif()
    file(READ \"${CMAKE_CURRENT_BINARY_DIR}/qt.build.\${CMAKE_INSTALL_CONFIG_NAME}\" _b)
    string(REPLACE \"@PREFIX@\" \"\${CMAKE_INSTALL_PREFIX}\" _b \"\${_b}\")
    message(STATUS \"Installing: \${_dest} (qtc's path set)\")
    file(WRITE \"\${_dest}\" \"\${_b}\")
    list(APPEND CMAKE_INSTALL_MANIFEST_FILES \"\${_dest}\")
  ")
else()
  install(FILES qt.build DESTINATION "${GOOSE_QT_INSTALL_DIR}")
endif()

# cmake --build build --target uninstall: removes what the last install put in place
if(NOT TARGET uninstall)
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/uninstall.cmake" "
    set(_m \"${CMAKE_CURRENT_BINARY_DIR}/install_manifest.txt\")
    if(NOT EXISTS \"\${_m}\")
      message(FATAL_ERROR \"nothing to uninstall: \${_m} is missing (install first)\")
    endif()
    file(STRINGS \"\${_m}\" _files)
    foreach(_f IN LISTS _files)
      if(EXISTS \"\$ENV{DESTDIR}\${_f}\" OR IS_SYMLINK \"\$ENV{DESTDIR}\${_f}\")
        message(STATUS \"Removing: \$ENV{DESTDIR}\${_f}\")
        file(REMOVE \"\$ENV{DESTDIR}\${_f}\")
      endif()
    endforeach()
  ")
  add_custom_target(uninstall COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_BINARY_DIR}/uninstall.cmake"
                    COMMENT "Removing the installed files")
endif()

# cmake --build build --target goose_qt_api: regenerates api.goose from qtc's manifest
find_package(Python3 COMPONENTS Interpreter QUIET)
if(Python3_FOUND AND EXISTS "${_qtc_manifest}")
  add_custom_target(goose_qt_api
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/gen/generate_goose.py"
            --manifest "${_qtc_manifest}" --out "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "Generating api.goose from ${_qtc_manifest}" VERBATIM)
endif()

# ------------------------------------------------------------------ tests

if(GOOSE_QT_TESTS AND GOOSE_EXECUTABLE)
  enable_testing()
  find_program(_bash NAMES bash)
  if(_bash)
    set(_env "GOOSE=${GOOSE_EXECUTABLE}" "QTC_LIB=$<TARGET_FILE_DIR:${_qtc}>")
    add_test(NAME goose_qt_tests COMMAND "${_bash}" "${CMAKE_CURRENT_SOURCE_DIR}/test/run.sh")
    add_test(NAME goose_qt_examples COMMAND "${_bash}" "${CMAKE_CURRENT_SOURCE_DIR}/examples/run.sh")
    add_test(NAME goose_qt_samples COMMAND "${_bash}" "${CMAKE_CURRENT_SOURCE_DIR}/samples/run.sh" --quick)
    set_tests_properties(goose_qt_tests goose_qt_examples goose_qt_samples PROPERTIES ENVIRONMENT "${_env}" TIMEOUT 3600)
    # installs into a scratch prefix and runs a program that imports goose-qt from there with no
    # library path set: what a user gets from cmake --install
    add_test(NAME goose_qt_installed
      COMMAND "${CMAKE_COMMAND}" -DBUILD_DIR=${CMAKE_BINARY_DIR} -DPREFIX=${CMAKE_CURRENT_BINARY_DIR}/test_prefix
              -DPKG=${GOOSE_QT_INSTALL_DIR} -DGOOSE=${GOOSE_EXECUTABLE} -DCONFIG=$<CONFIG>
              -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/installed_test.cmake")
    set_tests_properties(goose_qt_installed PROPERTIES TIMEOUT 1200)
  else()
    message(STATUS "goose-qt: no bash found: the tests are left out")
  endif()
endif()
