locals {
  pool_ids = { for idx, pool in ibm_is_lb_pool.alb_backend_pools : pool.name => pool.id }
}