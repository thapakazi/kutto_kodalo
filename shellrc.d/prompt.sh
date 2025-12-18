# Add the following to your ~/.zshrc

# Enable prompt substitution
setopt PROMPT_SUBST

function build_custom_prompt() {
    # Check if we are inside a Git work tree.
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # Get the current directory relative to the Git root.
        local relative_path=$(git rev-parse --show-prefix)

        # Get the base name of the Git project (the top-level directory).
        local git_root_name=$(basename "$(git rev-parse --show-toplevel)")

        # Prepare the abbreviated path string.
        local abbreviated_path="$git_root_name:"

        # Dynamically build the path by iterating through components.
        # This will get the relative path and abbreviate all parts except the last.
        # We start by storing all path components in an array.
        local path_parts=("${(@s:/:)relative_path}")
        
        # Build the abbreviated path.
        if [ ${#path_parts[@]} -gt 1 ]; then
            # Iterate through all but the last component, appending the first letter.
            local i=1
            while [ $i -lt ${#path_parts[@]} ]; do
                abbreviated_path+="/${path_parts[i][1]}"
                i=$((i+1))
            done
            # Append the last component in full.
            abbreviated_path+="/${path_parts[-1]}"
        fi

        # Print the final prompt with colors.
        echo "%F{cyan}$abbreviated_path %f$ "
    else
        # Not in a Git project, show only the current directory basename.
        echo "%F{yellow}%c%f$ "
    fi
}

# Set the PROMPT variable, calling the function on every new prompt.
PROMPT='$(build_custom_prompt)'
