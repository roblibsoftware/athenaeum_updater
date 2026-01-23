
call download_clone.cmd



for /F "tokens=1,2" %%i in (one_file_list.txt) do (
    echo %%i %%j
    call update.cmd %%i %%j
)
