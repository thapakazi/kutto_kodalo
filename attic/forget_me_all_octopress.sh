# old home, gone :(
export OCTO_HOME="~/octopress"
ogen () {
  cd $OCTO_HOME; rake generate; cd -
}

osave () {
  cd $OCTO_HOME; git commit -am "Updates" && git push origin source; cd -
}

odeploy () {
  cd $OCTO_HOME; osave; rake gen_deploy; cd -
}

# this one is for orgmode only
opost() {
  cd $OCTO_HOME
  output=$(rake "new_post[${1}]")
  new_file=$(echo $output | awk '{print $4}')
  base=$(basename $new_file)
  new_location=$OCTO_HOME/source/org_posts/
  mv $OCTO_HOME/$new_file $new_location
  echo created $new_location/$base
  cd -
}

opage() {
  cd $OCTO_HOME
  rake "new_page[${1}]"
  cd -
}
