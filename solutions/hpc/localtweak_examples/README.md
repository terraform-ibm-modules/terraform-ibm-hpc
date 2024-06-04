The files in this directory are not normally included in the Terraform plan.
If you want to enable one of them in your deployment, just copy it to the base directory of the project (one level up from here),
or make a symlink if no customization is needed. Always be sure the new name ends with "*.tf".
For example:
  cd solutions/hpc
  ln -s localtweak_examples/localtweak___ALLOW_MY_IP_override.tf.txt localtweak___ALLOW_MY_IP_override.tf

They add resources and/or use the "override" Terraform feature to modify the local deployment in ways that you do not want to commit to the standard code.
(note how the .gitignore file in the root directory mentions "localtweak__*.tf" files to avoid committing them accidentally)
In some cases additional configuration is required on your system (see "*_extras" directories).
