###################################################
# Copyright (C) IBM Corp. 2024 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

##############################################################################
# Outputs
##############################################################################

output "cluster_info" {
  value       = module.hpc_basic_example
  description = "Hpcaas cluster information."
}
