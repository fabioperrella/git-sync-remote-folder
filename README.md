# git-sync-remote-folder

A script to sync a local folder with a remote one

## Instructions to use it:

- download `git_sync.sh` from this repository
- load this file in your .bashrc (or zsh): 
```
source git_sync.sh
```
- install fswatch:
```
brew install fswatch
```
- make sure your local folder is using the same git ref as your remote folder (the same commit)
- go to your local folder (cd LOCAL_FOLDER)
- run `watch_sync HOSTNAME ABSULOTE_REMOTE_PATH`, for example `watch_sync app.dev /usr/local/git_tree/main`

After this, every change you do in your local folder will be automatically synced to your remote folder
