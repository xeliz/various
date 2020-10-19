#!/bin/bash

# apco (application container): simple background process/service manager
# 
# Deploy:
# 1. create app directory in apps/
# 2. create apps/run.sh, which starts an application and saves its PID to file named "pid"
# 
# Start: apco start <APP DIRECTORY NAME>
# Stop: apco stop <APP DIRECTORY NAME>
# List apps: apco list
# Install: apco install app-name "command to run" files...
# Remove: apco remove app-name
#
# TODO:
# - stop scripts: some programs cannot be stopped only be killing their processes.
# - some programs like postgresql manage processes themselves, so default run script is not applicable here.
# - restart command


DIR=`dirname $0`

pushd . >/dev/null
cd $DIR
if [ ! -e apps ]; then
    mkdir apps
fi
if [ ! -e run ]; then
    mkdir run
fi
popd >/dev/null

refresh() {
    for app in `ls $DIR/run`; do
        pid=`cat $DIR/run/$app`
        if ! kill -0 $pid 2>/dev/null; then
            echo "$app died, PID $pid"
            rm $DIR/run/$app
        fi
    done
}

case "$1" in
    start)
        refresh
        if [ -z "$2" ]; then
            echo "Specify service name"
            exit 1
        fi
        if [ -e "$DIR/run/$2" ]; then
            echo "Already started"
            exit 1
        fi
        pushd . >/dev/null
        cd $DIR/apps
        flag=0
        for dir in `ls`; do
            for file in `ls $dir`; do
                if [ "$file" = "run-$2.sh" ]; then
                    flag=1
                    cd $dir
                    echo "Starting '$2'..."
                    ./run-$2.sh &>/dev/null
                    mv pid $DIR/run/$2
                    break 2
                fi
            done
        done
        if [ "$flag" -eq "0" ]; then
            echo "Service '$2' not found"
        fi
        popd >/dev/null
    ;;
    stop)
        refresh
        if [ ! -e "$DIR/run/$2" ]; then
            echo "Not started"
            exit 1
        fi
        echo "Stopping '$2'..."
        kill `cat $DIR/run/$2`
        rm $DIR/run/$2
    ;;
    list)
        refresh
        for dir in `ls $DIR/apps`; do
            for file in `ls $DIR/apps/$dir/run-*.sh`; do
                app=`basename $file | sed -e 's/run-\(.*\)\.sh/\1/'`
                if [ -e "$DIR/run/$app" ]; then
                    echo "$app [ running ]"
                else
                    echo "$app"
                fi
            done
        done
    ;;
    install)
        refresh
        if [ -e "$DIR/apps/$2" ]; then
            echo "Already installed"
            exit 1
        fi
        echo "Installing $2..."
        mkdir $DIR/apps/$2
        printf "#!/bin/bash\n\n$3 &>log &\necho \$! >pid" > $DIR/apps/$2/run-$2.sh
        if [ ! -z "${@:4}" ]; then
            cp ${@:4} $DIR/apps/$2/
        fi
    ;;
    remove)
        refresh
        if [ ! -e "$DIR/apps/$2" ]; then
            echo "Not installed"
            exit 1
        fi
        echo "Removing $2..."
        rm -rf $DIR/apps/$2
    ;;
    *)
        refresh
        echo 'Specify command'
    ;;
esac

