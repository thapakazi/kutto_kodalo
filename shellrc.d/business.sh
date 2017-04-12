# google calendar 📆 meets the my terminal.
# me: terminal, nthis is Google Calendar
# me: Google Calendar, meet thi, this is terminal
# both: wave eachother...
# both: oh, gosh we can be a combo....
# [particle collider sound]...
# gcalcli, my name is gcalcli, I am blend of both terminal and calendar world, and  will change your habbit :) soon
# end of story

# credits: to creators and all envolved
# url: https://github.com/insanum/gcalcli
# asssuming you have set your config folders inside this folder
GCALCLI_CONFIG_DIR=$HOME/.gcalcli

# generic function to do same thing on both of the servers
# default: is to list the agenda
gcalcli_all(){
    action=${1:-agenda}
    ls -1 $GCALCLI_CONFIG_DIR | xargs -I {} gcalcli --configFolder $GCALCLI_CONFIG_DIR/{} ${action}
}

# TODO: run thing parallel 🤔
# generic function to do same thing on both of the servers parallel
# using this awesome tool: https://github.com/fd0/machma
# gcalcli_all_m(){
#     action=${1:-agenda}
#     ls -1 $GCALCLI_CONFIG_DIR | machma -p 2 gcalcli --configFolder $GCALCLI_CONFIG_DIR/{} ${action}
# }

