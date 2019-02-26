# find and kill service on port
killp(){
    process=$(lsof -t -i:${1:-3001}|xargs)
    echo "killing process $Red ${process} $Color_Off"
    kill -9 $(lsof -t -i:${1:-3001})
}
