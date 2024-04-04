resource "ibm_is_lb" "alb" {
  count           = var.create_load_balancer ? 1 : 0
  name            = format("%s-alb", var.prefix)
  resource_group  = var.resource_group_id
  type            = var.alb_type
  security_groups = var.security_group_ids
  subnets         = [var.bastion_subnets[0].id]
}

resource "ibm_is_lb_pool" "alb_backend-pools" {
  count                           = var.create_load_balancer ? length(var.alb_pools) : 0
  name                            = format(var.alb_pools[count.index]["name"], var.prefix)
  lb                              = ibm_is_lb.alb[0].id
  algorithm                       = var.alb_pools[count.index]["algorithm"]
  protocol                        = var.alb_pools[count.index]["protocol"]
  health_delay                    = var.alb_pools[count.index]["health_delay"]
  health_retries                  = var.alb_pools[count.index]["health_retries"]
  health_timeout                  = var.alb_pools[count.index]["health_timeout"]
  health_type                     = var.alb_pools[count.index]["health_type"]
  health_monitor_url              = var.alb_pools[count.index]["health_monitor_url"]
  health_monitor_port             = var.alb_pools[count.index]["health_monitor_port"]
  session_persistence_type        = var.alb_pools[count.index]["session_persistence_type"]
}

resource "ibm_is_lb_listener" "alb_frontend-listener" {
  count                 = var.create_load_balancer ? length(var.alb_pools) : 0
  lb                    = ibm_is_lb.alb[0].id
  port                  = var.alb_pools[count.index]["lb_pool_listener"]["port"]
  protocol              = var.alb_pools[count.index]["lb_pool_listener"]["protocol"]
  certificate_instance  = var.certificate_instance
  default_pool          = lookup(local.pool_ids, format(var.alb_pools[count.index]["name"], var.prefix), null)
}

 resource "ibm_is_lb_pool_member" "alb_candidate_members_0" {
  count       = var.create_load_balancer ? length(var.vsi_ids) : 0
  lb          = ibm_is_lb.alb[0].id
  pool        = element(split("/", lookup(local.pool_ids, format(var.alb_pools[0]["name"], var.prefix), null)), 1)
  port        = var.alb_pools[0]["lb_pool_members_port"]
  target_id   = var.vsi_ids[count.index]["id"]
}

resource "ibm_is_lb_pool_member" "alb_candidate_members_1" {
  count       = var.create_load_balancer ? length(var.vsi_ids) : 0
  lb          = ibm_is_lb.alb[0].id
  pool        = element(split("/", lookup(local.pool_ids, format(var.alb_pools[1]["name"], var.prefix), null)), 1)
  port        = var.alb_pools[1]["lb_pool_members_port"]
  target_id   = var.vsi_ids[count.index]["id"]
} 
