@echo off
setlocal EnableDelayedExpansion

rmdir /s /q .camel-jbang-run 2>nul

set "JAVA_FILES="

for /r "src\main\java" %%F in (*.java) do (

    rem Check if Java file contains main() function
    findstr /r /c:"main[ ]*(" "%%F" >nul

    if errorlevel 1 (
        rem No main() found - include the file
        set "JAVA_FILES=!JAVA_FILES! "%%F""
        echo INCLUDED: %%F
    ) else (
        rem main() found - skip this file and continue with next file
        echo SKIPPED:  %%F
    )
)

echo.
echo Java files to run:
echo !JAVA_FILES!
echo.

camel kubernetes run !JAVA_FILES! ^
    --cluster-type=kubernetes ^
    --name=apachemcamel ^
    --image-group=camel-poc ^
    --image-registry=host.docker.internal:5000 ^
    --trait container.image-pull-policy=Always ^
    --trait container.port=8080 ^
    --verbose

endlocal