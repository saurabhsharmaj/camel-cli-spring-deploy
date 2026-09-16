@echo off
setlocal

rmdir /s /q .camel-jbang-run
camel kubernetes run src\main\java\com\example\camel_code\* src\main\java\com\example\camel_code\utils\* ^
    --cluster-type=kubernetes ^
    --name=apachemcamel ^
    --image-group=camel-poc ^
    --image-registry=host.docker.internal:5000 ^
    --trait container.image-pull-policy=Always ^
    --trait container.port=8080 ^
    --verbose