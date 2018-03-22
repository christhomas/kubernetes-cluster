#!/usr/bin/env bash

red=$'\e[1;31m'; grn=$'\e[1;32m'; end=$'\e[0m'

if [[ "$1" = "skip" ]] || [[ "$1" = "no-skip" ]]; then
    git update-index --$1-worktree *gitlab-secrets*
    git status

    if [[ "$1" = "skip" ]]; then
        echo "${grn}File should be missing from git status${end}";
    fi

    if [[ "$1" = "no-skip" ]]; then
        echo "${red}FILE SHOULD BE IN STATUS LIST, BE CAREFUL!!${end}";
    fi
else
    echo "${red}First parameter can only be 'skip' or 'no-skip'${end}"
    exit 1
fi
