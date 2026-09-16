@echo off
setlocal EnableDelayedExpansion

rmdir /s /q .camel-jbang-run 2>nul

set "JAVA_FILES="

for /r "src\main\java" %%F in (*.java) do (
    set "JAVA_FILES=!JAVA_FILES! "%%F""
)

echo Java files:
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