# --------------------------------------------------------------------------
# the directory name
set(directory doc/code_examples)

# --------------------------------------------------------------------------
# list all filenames of the directory here
set(executables_list
Tutorial_GUI_ListEditor
Tutorial_GUI_ParamEditor
Tutorial_GUI_Plot1D
)

# pass source file list to the upper instance
set(GUI_EXAMPLES_executables ${GUI_EXAMPLES_executables} ${executables_list})

# --------------------------------------------------------------------------
# add filenames to Visual Studio solution tree
set(sources_VS)
foreach(i ${executables_list})
	list(APPEND sources_VS "${i}.cpp")
endforeach(i)
source_group("EXAMPLES" FILES ${sources_VS})
