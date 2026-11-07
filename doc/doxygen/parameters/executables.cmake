### the directory name
set(directory doc/doxygen/parameters)

### the documenters of the GUI layer (see doc/CMakeLists.txt)
set(sources_list
GUIParamDocumenter
GUIToolDocumenter
)

### pass source file list to the upper instance
set(OpenMS_doc_executables ${sources_list})

### source group definition
set(sources)
foreach(i ${sources_list})
  list(APPEND sources ${i}.cpp)
endforeach()
source_group("Source Files\\doc\\doxygen\\parameters" FILES ${sources})
