config.define_string("windows-bash-path", args=False, usage="Path to bash.exe for windows")
config.define_string("test-data-path", args=False, usage="Path to test data sql file")
config.define_string("lobby-server-path", args=False, usage="Path to lobby server repository")
config.define_string_list("to-run", args=True)
cfg = config.parse()
windows_bash_path = cfg.get("windows-bash-path", "C:\\Program Files\\Git\\bin\\bash.exe")
if os.name == "nt" and not os.path.exists(windows_bash_path):
    fail("Windows users need to supply a valid path to a bash executable")
    
def as_windows_command(command):
    if type(command) == "list":
        return [windows_bash_path, "-c"] + [" ".join(command)]
    else:
        fail("Unknown command type")

    
k8s_yaml("deploy/standard/traefik_crds.yaml")
k8s_yaml("deploy/standard/traefik.yaml")
k8s_resource(new_name="traefik_crds", objects=["ingressroutes.traefik.io","middlewares.traefik.io","ingressroutetcps.traefik.io","ingressrouteudps.traefik.io","middlewaretcps.traefik.io","serverstransports.traefik.io","serverstransporttcps.traefik.io","tlsoptions.traefik.io","tlsstores.traefik.io","traefikservices.traefik.io"], labels=["traefik"])
k8s_resource(workload="traefik-deployment", objects=["traefik-ingress-controller:clusterrole","traefik-ingress-controller:clusterrolebinding","traefik-ingress-controller:serviceaccount","traefik:ingressroute"], labels=["traefik"], links=["http://traefik.localhost"])

k8s_yaml("deploy/standard/mariadb.yaml")
setup_db_command = ["scripts/setup-db.sh"]
local_resource(name = "setup-db", allow_parallel = True, cmd = setup_db_command, cmd_bat = as_windows_command(setup_db_command), resource_deps=["faf-db"], labels=["database"])
populate_db_command = ["scripts/populate-db.sh", cfg.get("test-data-path", "sql/test-data.sql")]
local_resource(name = "populate-db", allow_parallel = True, cmd = populate_db_command, cmd_bat = as_windows_command(populate_db_command), resource_deps=["faf-db-migrate"], labels=["database"])
populate_db_command = ["scripts/populate-coturn.sh"]
local_resource(name = "populate-coturn", allow_parallel = True, cmd = populate_db_command, cmd_bat = as_windows_command(populate_db_command), resource_deps=["faf-ice-breaker"], labels=["database"])
k8s_resource(workload="faf-db", port_forwards="3306", labels=["database"])
k8s_resource(workload="faf-db-migrate", resource_deps=["setup-db"], labels=["database"])

k8s_yaml("deploy/standard/rabbitmq.yaml")
setup_rabbit_command = ["scripts/setup-rabbitmq.sh"]
local_resource(name = "setup-rabbitmq", allow_parallel = True, cmd = setup_rabbit_command, cmd_bat = as_windows_command(setup_rabbit_command), resource_deps=["rabbitmq"], labels=["messaging"])
k8s_resource(workload="rabbitmq", objects=["rabbitmq:configmap","rabbitmq:ingressroute"], port_forwards=["5672", "15672"], resource_deps=["traefik_crds"], labels=["messaging"], links=["http://rabbitmq.localhost"])

k8s_yaml("deploy/standard/ory-hydra.yaml")
setup_hydra_command = ["scripts/setup-hydra-clients.sh"]
local_resource(name = "setup-hydra-clients", allow_parallel = True, cmd = setup_hydra_command, cmd_bat = as_windows_command(setup_hydra_command), resource_deps=["ory-hydra"], labels=["authentication"])
k8s_resource(workload="ory-hydra-migrate", objects=["ory-hydra:configmap"], resource_deps=["faf-db"], labels=["authentication"])
k8s_resource(workload="ory-hydra", objects=["ory-hydra:ingressroute"], port_forwards=["4444","4445"], resource_deps=["ory-hydra-migrate","traefik_crds"], labels=["authentication"], links=["http://hydra.localhost/.well-known/openid-configuration"])

k8s_yaml("deploy/standard/faf-replay-server.yaml")
k8s_resource(workload="faf-replay-server", objects=["faf-replay-server:configmap"], port_forwards=["15000"], resource_deps=["faf-db-migrate"], labels=["client"])

k8s_yaml("deploy/standard/faf-user-service.yaml")
k8s_resource(workload="faf-user-service", objects=["faf-user-service:configmap", "faf-user-service-mail-templates","faf-user-service:ingressroute"], port_forwards=["8080"], resource_deps=["setup-hydra-clients", "faf-db-migrate","traefik_crds","populate-db"], labels=["client"], links=["http://user.localhost"])

k8s_yaml("deploy/standard/faf-api.yaml")
k8s_resource(workload="faf-api", objects=["faf-api:configmap", "faf-api-mail-templates", "faf-api-api:ingressroute", "faf-api-web:ingressroute"], resource_deps=["faf-db-migrate", "setup-rabbitmq","traefik_crds","populate-db"], labels=["client"], links=["http://api.localhost"])

k8s_yaml("deploy/standard/faf-ice-breaker.yaml")
k8s_resource(workload="faf-ice-breaker", objects=["faf-ice-breaker:configmap", "faf-ice-breaker-stripprefix", "faf-ice-breaker-api:ingressroute", "faf-ice-breaker-web:ingressroute"], resource_deps=["faf-db-migrate", "ory-hydra", "setup-rabbitmq", "traefik_crds"], labels=["client"], links=["http://api.localhost/ice"])

if cfg.get("lobby-server-path"):
    k8s_yaml("deploy/local/faf-lobby-server.yaml")
    docker_build("local/faf-python-server", cfg.get("lobby-server-path"))
else:
    k8s_yaml("deploy/standard/faf-lobby-server.yaml")
    
k8s_resource(workload="faf-lobby-server", objects=["faf-lobby-server:configmap"], resource_deps=["faf-db-migrate", "ory-hydra", "setup-rabbitmq"], labels=["client"])

k8s_yaml("deploy/standard/faf-ws-bridge.yaml")
k8s_resource(workload="faf-ws-bridge", port_forwards=["8003","8002"], labels=["client"])

k8s_yaml("deploy/standard/faf-league-service.yaml")
k8s_resource(workload="faf-league-service", objects=["faf-league-service:configmap"], resource_deps=["setup-db", "setup-rabbitmq"], labels=["client"])

groups = {
    "client": ["faf-api", "faf-ws-bridge", "faf-replay-server", "faf-league-service", "faf-user-service", "populate-coturn"],
    "api": ["faf-api", "faf-user-service"]
}

resources = []
for arg in cfg.get("to-run", []):
  if arg in groups:
    resources += groups[arg]
  else:
    # also support specifying individual services instead of groups, e.g. `tilt up a b d`
    resources.append(arg)
    
config.set_enabled_resources(resources)
