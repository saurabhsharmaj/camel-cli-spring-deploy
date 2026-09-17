@echo off
setlocal EnableDelayedExpansion

echo.
echo ==========================================================
echo          CAMEL KUBERNETES DEPLOYMENT
echo ==========================================================
echo.


REM ==========================================================
REM Configuration
REM ==========================================================

set "APP_NAME=apachemcamel"
set "IMAGE_GROUP=camel-poc"
set "IMAGE_REGISTRY=host.docker.internal:5000"
set "LOCAL_PORT=8081"
set "CONTAINER_PORT=80"

set "DEP_FILE=%TEMP%\camel-maven-deps-%RANDOM%.txt"


REM ==========================================================
REM Step 1: Clean previous Camel JBang export
REM ==========================================================

echo ==========================================================
echo Step 1 - Cleaning previous Camel JBang export
echo ==========================================================
echo.

if exist ".camel-jbang-run" (
    rmdir /s /q ".camel-jbang-run" 2>nul
)

echo Cleanup completed.
echo.


REM ==========================================================
REM Step 2: Validate project
REM ==========================================================

echo ==========================================================
echo Step 2 - Validating project
echo ==========================================================
echo.

if not exist "pom.xml" (
    echo ERROR: pom.xml was not found.
    echo Current directory:
    cd
    goto :error
)

if not exist "src\main\java" (
    echo ERROR: src\main\java directory was not found.
    goto :error
)

echo pom.xml found.
echo Java source directory found.
echo.


REM ==========================================================
REM Step 3: Discover Java files
REM ==========================================================

echo ==========================================================
echo Step 3 - Discovering Java source files
echo ==========================================================
echo.

set "JAVA_FILES="

for /r "src\main\java" %%F in (*.java) do (

    rem Check whether file contains main() method
    findstr /r /c:"main[ ]*(" "%%F" >nul

    if errorlevel 1 (

        rem No main() method - include this Java file
        set "JAVA_FILES=!JAVA_FILES! "%%F""

        echo INCLUDED:
        echo   %%F

    ) else (

        rem main() method found - skip file
        echo SKIPPED:
        echo   %%F
    )
)

echo.


REM ==========================================================
REM Validate Java files
REM ==========================================================

if "!JAVA_FILES!"=="" (
    echo ERROR: No Java source files were discovered.
    goto :error
)

echo ==========================================================
echo Java files selected for Camel CLI
echo ==========================================================
echo.

echo !JAVA_FILES!
echo.


REM ==========================================================
REM Step 4: Resolve Maven dependencies
REM
REM IMPORTANT:
REM
REM We capture Maven's normal console output instead of using
REM dependency:list -DoutputFile.
REM
REM This makes parsing reliable on Windows.
REM ==========================================================

echo ==========================================================
echo Step 4 - Resolving Maven dependencies from pom.xml
echo ==========================================================
echo.

if exist "%DEP_FILE%" (
    del /q "%DEP_FILE%" 2>nul
)

echo Maven will resolve:
echo   - dependency versions
echo   - dependencyManagement
echo   - parent POM
echo   - BOM versions
echo   - Maven properties
echo.

echo Transitive dependencies will NOT be passed to Camel CLI.
echo.

echo Running Maven dependency:list...
echo.


call mvn dependency:list ^
    -DexcludeTransitive=true ^
    -DincludeScope=runtime > "%DEP_FILE%" 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: Maven dependency:list failed.
    echo.
    echo Maven output:
    type "%DEP_FILE%"
    goto :error
)

echo.
echo Maven dependency resolution completed.
echo.


REM ==========================================================
REM Step 5: Show the dependency lines Maven returned
REM
REM This is intentionally displayed so that if something goes
REM wrong in the future, we can immediately see what Maven
REM returned.
REM ==========================================================

echo ==========================================================
echo Step 5 - Maven dependency output
echo ==========================================================
echo.

findstr /R /C:"\[INFO\].*:[^:]*:[^:]*:[^:]*:[^:]*" "%DEP_FILE%"

echo.


REM ==========================================================
REM Step 6: Extract application dependencies
REM
REM Maven format:
REM
REM [INFO]    org.json:json:jar:20220320:compile
REM
REM Converted to:
REM
REM org.json:json:20220320
REM
REM
REM EXCLUDED:
REM
REM org.apache.camel.springboot:*
REM org.springframework.boot:*
REM org.apache.camel:*
REM org.apache.camel.quarkus:*
REM io.quarkus:*
REM io.quarkiverse:*
REM org.jboss:*
REM
REM These belong to the runtime/platform and should be managed
REM by the generated Quarkus/Camel application.
REM ==========================================================

echo ==========================================================
echo Step 6 - Extracting application dependencies
echo ==========================================================
echo.

set "MAVEN_DEPS="

for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command ^
    "$lines = Get-Content '%DEP_FILE%';" ^
    "$deps = foreach ($line in $lines) {" ^
    "    $line = $line.Trim();" ^
    "    if ($line -match '^\[INFO\]\s+([A-Za-z0-9_.-]+):([A-Za-z0-9_.-]+):([^:]+):([^:]+):(compile|runtime)') {" ^
    "        $g = $matches[1];" ^
    "        $a = $matches[2];" ^
    "        $v = $matches[4];" ^
    "        if (" ^
    "            $g -notmatch '^org\.apache\.camel\.springboot$' -and" ^
    "            $g -notmatch '^org\.springframework(\.|$)' -and" ^
    "            $g -notmatch '^org\.apache\.camel\.quarkus$' -and" ^
    "            $g -notmatch '^org\.apache\.camel$' -and" ^
    "            $g -notmatch '^io\.quarkus(\.|$)' -and" ^
    "            $g -notmatch '^io\.quarkiverse(\.|$)' -and" ^
    "            $g -notmatch '^org\.jboss(\.|$)'" ^
    "        ) {" ^
    "            $g + ':' + $a + ':' + $v" ^
    "        }" ^
    "    }" ^
    "};" ^
    "$deps | Sort-Object -Unique" ^
`) do (

    if "!MAVEN_DEPS!"=="" (
        set "MAVEN_DEPS=%%D"
    ) else (
        set "MAVEN_DEPS=!MAVEN_DEPS!,%%D"
    )

    echo INCLUDED DEP:
    echo   %%D
)

echo.


REM ==========================================================
REM Step 7: Display final dependencies
REM ==========================================================

echo ==========================================================
echo Step 7 - Final dependencies passed to Camel CLI
echo ==========================================================
echo.

if "!MAVEN_DEPS!"=="" (

    echo WARNING: No additional application dependencies detected.
    echo.
    echo If your pom.xml contains external dependencies such as
    echo org.json, this indicates a dependency parsing problem.
    echo.
    echo Raw Maven output is available at:
    echo %DEP_FILE%
    echo.

) else (

    echo !MAVEN_DEPS!
)

echo.


REM ==========================================================
REM Step 8: Run Camel Kubernetes
REM ==========================================================

echo ==========================================================
echo Step 8 - Starting Camel Kubernetes deployment
echo ==========================================================
echo.

echo Application:
echo   %APP_NAME%
echo.

echo Runtime:
echo   Quarkus
echo.

echo Image:
echo   %IMAGE_REGISTRY%/%IMAGE_GROUP%/%APP_NAME%
echo.


if "!MAVEN_DEPS!"=="" (

    echo Running Camel CLI without additional dependencies...
    echo.

    camel kubernetes run !JAVA_FILES! ^
        --runtime=quarkus ^
        --cluster-type=kubernetes ^
        --name=%APP_NAME% ^
        --image-group=%IMAGE_GROUP% ^
        --image-registry=%IMAGE_REGISTRY% ^
        --trait container.image-pull-policy=Always ^
        --trait container.port=8080 ^
        --verbose

) else (

    echo Running Camel CLI with:
    echo.
    echo !MAVEN_DEPS!
    echo.

    camel kubernetes run !JAVA_FILES! ^
        --runtime=quarkus ^
        --dep=!MAVEN_DEPS! ^
        --cluster-type=kubernetes ^
        --name=%APP_NAME% ^
        --image-group=%IMAGE_GROUP% ^
        --image-registry=%IMAGE_REGISTRY% ^
        --trait container.image-pull-policy=Always ^
        --trait container.port=8080 ^
        --verbose
)


REM ==========================================================
REM Check Camel CLI result
REM ==========================================================

if errorlevel 1 (

    echo.
    echo ==========================================================
    echo ERROR: Camel Kubernetes deployment failed!
    echo ==========================================================
    echo.

    goto :error
)


REM ==========================================================
REM Step 9: Verify generated POM
REM ==========================================================

echo.
echo ==========================================================
echo Step 9 - Verifying generated Quarkus POM
echo ==========================================================
echo.

if exist ".camel-jbang-run\%APP_NAME%\pom.xml" (

    echo Generated POM:
    echo .camel-jbang-run\%APP_NAME%\pom.xml
    echo.

    echo ----------------------------------------------------------
    echo Checking org.json
    echo ----------------------------------------------------------
    echo.

    findstr /I /C:"org.json" ".camel-jbang-run\%APP_NAME%\pom.xml"

    if errorlevel 1 (
        echo WARNING: org.json was NOT found in generated POM.
    ) else (
        echo SUCCESS: org.json found in generated POM.
    )

    echo.

    echo ----------------------------------------------------------
    echo Checking Spring Boot dependencies
    echo ----------------------------------------------------------
    echo.

    findstr /I /C:"spring-boot" ".camel-jbang-run\%APP_NAME%\pom.xml"

    echo.

    echo ----------------------------------------------------------
    echo Checking Camel Spring Boot dependencies
    echo ----------------------------------------------------------
    echo.

    findstr /I /C:"camel-spring-boot" ".camel-jbang-run\%APP_NAME%\pom.xml"

) else (

    echo WARNING:
    echo Generated POM could not be found.
)

echo.


REM ==========================================================
REM Step 10: Wait for Kubernetes deployment
REM ==========================================================

echo ==========================================================
echo Step 10 - Waiting for Kubernetes deployment
echo ==========================================================
echo.

kubectl rollout status deployment/%APP_NAME% --timeout=180s

if errorlevel 1 (

    echo.
    echo ==========================================================
    echo ERROR: Deployment did not become READY.
    echo ==========================================================
    echo.

    echo Kubernetes Pods:
    echo.

    kubectl get pods

    echo.
    echo Kubernetes Deployment:
    echo.

    kubectl get deployment %APP_NAME%

    echo.
    echo Recent application logs:
    echo.

    kubectl logs deployment/%APP_NAME% --tail=200

    goto :error
)


REM ==========================================================
REM Step 11: Deployment successful
REM ==========================================================

echo.
echo ==========================================================
echo              DEPLOYMENT SUCCESSFUL
echo ==========================================================
echo.

kubectl get deployment %APP_NAME%

echo.
kubectl get pods

echo.


REM ==========================================================
REM Step 12: Port forwarding
REM ==========================================================

echo ==========================================================
echo Step 12 - Starting port forwarding
echo ==========================================================
echo.

echo Application available at:
echo.
echo http://localhost:%LOCAL_PORT%
echo.

echo Press Ctrl+C to stop port forwarding.
echo.

kubectl port-forward service/%APP_NAME% %LOCAL_PORT%:%CONTAINER_PORT%

goto :end


REM ==========================================================
REM Error handler
REM ==========================================================

:error

echo.
echo ==========================================================
echo                 START.BAT FAILED
echo ==========================================================
echo.

echo Useful troubleshooting commands:
echo.
echo   kubectl get pods
echo   kubectl get deployment %APP_NAME%
echo   kubectl logs deployment/%APP_NAME% --tail=200
echo   kubectl describe deployment %APP_NAME%
echo.

:end

if exist "%DEP_FILE%" (
    del /q "%DEP_FILE%" 2>nul
)

endlocal
