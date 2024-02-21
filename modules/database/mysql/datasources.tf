data "ibm_database_connection" "db_connection" {
    deployment_id = ibm_database.itself.id
    user_id = ibm_database.itself.adminuser
    user_type = "database"
    endpoint_type = ibm_database.itself.service_endpoints
}  