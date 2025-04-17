#!/usr/bin/env nu
# Author: hustcer
# Created: 2025/02/08 19:02:15
# Description: A wrapper for nu/review.nu as the main entry point of the project.

use utils/common.nu [hr-line, ECODE]
use actions/code-review.nu [deepseek-review]

# Use DeepSeek AI to review code changes locally
def main [
  token?: string,           # Your DeepSeek API token, fallback to CHAT_TOKEN env var
  --debug(-d),              # Debug mode
  --output(-o): string,     # Output file path
  --paths(-p): string,      # Comma separated file paths to review
  --diff-to(-t): string,    # Diff to git REF
  --diff-from(-f): string,  # Diff from git REF
  --patch-cmd(-c): string,  # The `git show` or `git diff` command to get the diff content, for local CR only
  --max-length(-l): int,    # Maximum length of the content for review, 0 means no limit.
  --model(-m): string,      # Model name, or read from CHAT_MODEL env var, `deepseek-chat` by default
  --base-url(-b): string,   # DeepSeek API base URL, fallback to BASE_URL env var
  --chat-url(-U): string,   # DeepSeek Model chat full API URL, e.g. http://localhost:11535/api/chat
  --sys-prompt(-s): string  # Optional, System prompt message, fallback to SYSTEM_PROMPT env var
  --user-prompt(-u): string # Default to $DEFAULT_OPTIONS.USER_PROMPT,
  --include(-i): string,    # Comma separated file patterns to include in the code review
  --exclude(-x): string,    # Comma separated file patterns to exclude in the code review
  --temperature(-T): float, # Temperature for the model, between `0` and `2`, default value `1.0`
] {
  config-check
  config-load --debug=$debug --model=$model
  (
    deepseek-review $token
      --debug=$debug
      --paths=$paths
      --output=$output
      --base-url=$base_url
      --chat-url=$chat_url
      --diff-to=$diff_to
      --diff-from=$diff_from
      --model=$env.CHAT_MODEL
      --patch-cmd=$patch_cmd
      --max-length=$max_length
      --sys-prompt=$sys_prompt
      --user-prompt=$user_prompt
      --temperature=$temperature
      --include=($include | default $env.INCLUDE_PATTERNS?)
      --exclude=($exclude | default $env.EXCLUDE_PATTERNS?)
  )
}

# Check if the .termixrc file exists.
def file-exists [file: string] {
  if ($file | path exists) { return true }
  print -e $'The config file (ansi r)($file)(ansi reset) does not exist. '
  print -e $'Please copy the (ansi g).termixrc.example(ansi reset) file to create a new one.'
  exit $ECODE.MISSING_DEPENDENCY
}

# Check if the prompt keys exist in the .termixrc file
def check-prompts [options: record] {
  check-prompt $options user
  # System prompt is optional, so we don't exit if it's missing
  # check-prompt $options system
}

# Check if the specified type of prompt key exists in the .termixrc file
def check-prompt [options: record, type: string] {
  let prompt_key = $options.settings | get -i $'($type)-prompt' | default ''
  if ($prompt_key | is-empty) {
    print -e $'(ansi r)The ($type) prompt key is missing in `settings.($type)-prompt` .termixrc file.(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  let prompt = $options.prompts | get -i $type
    | get -i $prompt_key
    | get -i prompt
  if ($prompt | is-empty) {
    print -e $'The ($type) prompt (ansi r)($prompt_key)(ansi reset) is missing in `prompts.($type)` of .termixrc file.'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Check if the model providers and models are correctly configured in .termixrc
def check-providers [options: record] {
  # settings.provider correctly configured and related provider exists
  let provider_name = $options.settings.provider
  if ($provider_name | is-empty) {
    print -e $'(ansi r)The provider name is missing in `cr.settings.provider` of .termixrc file.(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  let provider_exists = $options.providers
    | where name == $provider_name
    | is-not-empty
  if not $provider_exists {
    print -e $'(ansi r)The provider ($provider_name) does not exist in `providers` of .termixrc file.(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  # Each provider should have name, token and models field
  $options.providers | each {|it|
    let empties = [name token models] | filter { |field| $it | get -i $field | is-empty }
    if ($empties | is-not-empty) {
      print -e $'Field (ansi r)`($empties | str join ,)`(ansi reset) should not be empty for provider:'
      $it | table -e -t psql | print
      exit $ECODE.INVALID_PARAMETER
    }
  }
}

# Check if the models are correctly configured in .termixrc
def check-models [options: record] {
  # Each model group should have one and only one enabled model
  $options.providers | each {|provider|
    let enabled_models = $provider.models | default false enabled | where enabled | length
    if ($enabled_models != 1) {
      print -e $'Model group (ansi r)`($provider.name)`(ansi reset) should have one and only one enabled model.'
      exit $ECODE.INVALID_PARAMETER
    }
  }
  # All models should have a name field
  $options.providers | each {|provider|
    $provider.models | enumerate | each {|e|
      if ($e.item.name? | is-empty) {
        print -e $'Model name is missing for provider (ansi r)`($provider.name)` model #($e.index)(ansi reset)...'
        exit $ECODE.INVALID_PARAMETER
      }
    }
  }
}

# Check if the .termixrc file exists and if it's valid
export def config-check [] {
  let config = [$env.TERMIX_DIR .termixrc] | path join
  file-exists $config
  let options = open $config | from toml | get cr
  check-prompts $options
  check-providers $options
  check-models $options
}

# Get model config information
def get-model-envs [settings: record, model?: string = ''] {
  let name = $settings.settings?.provider? | default ''
  let provider = $settings.providers
    | default []
    | where name == $name
    | get -i 0
    | default {}
  let model_name = $provider.models
    | default []
    | where {|it| if ($model | is-empty) {
        $it.enabled? | default false
      } else {
        $it.name == $model or $it.alias? == $model }
      }
    | get -i 0.name
    | default $model

  { CHAT_TOKEN: $provider.token?, BASE_URL: $provider.base-url?, CHAT_URL: $provider.chat-url?, CHAT_MODEL: $model_name }
}

# Load the .termixrc file to the environment
export def --env config-load [
  --debug(-d),                # Print the loaded environment variables
  --model(-m): string,        # Load the specified model by name
] {
  let default_settings = get-default-config
  let config = [$env.TERMIX_DIR .termixrc] | path join
  let all_settings = open $config | from toml | get cr? | default {}
  let merged = $default_settings | merge $all_settings
  let settings = $merged | get settings? | default {}

  let user_prompt = $merged.prompts?.user?
    | get -i $settings.user-prompt?
    | get -i prompt

  let system_prompt = $merged.prompts?.system?
    | get -i $settings.system-prompt?
    | get -i prompt

  let model_envs = get-model-envs $merged $model

  let env_vars = {
    ...$model_envs,
    USER_PROMPT: $user_prompt,
    SYSTEM_PROMPT: $system_prompt,
    MAX_LENGTH: $settings.max-length,
    TEMPERATURE: $settings.temperature,
    EXCLUDE_PATTERNS: $settings.exclude-patterns,
    INCLUDE_PATTERNS: $settings.include-patterns,
  }
  load-env $env_vars
  if $debug {
    print 'Loaded Environment Variables:'; hr-line
    $env_vars | table -t psql | print
  }
}

# Get the default config from the remote repo
export def get-default-config [] {
  cd $env.TERMIX_DIR
  let remote = git remote -v | detect columns -n
  if ($remote | is-empty) { return {} }
  let name = $remote | rename name url | where url =~ 'frontend-product/termix-nu' | get name.0
  do -i { git fetch $name i }
  git show origin/i:termixrc.toml | from toml | get cr? | default {}
}
