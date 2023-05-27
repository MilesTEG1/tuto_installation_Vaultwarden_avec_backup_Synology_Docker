#!/bin/bash
##==============================================================================================
##                                                                                            ##
##                   Script vaultwarden__Enable_Websocket_DSM6_DSM7.sh                        ##
##                                                                                            ##
##          Source : https://gist.github.com/nstanke/3949ae1c4706854d8f166d1fb3dadc81         ##
##                                                                                            ##
##==============================================================================================
##                                                                                            ##
##   Ce script pemet de router ce qui ne peut pas être fait avec le reverse-proxy             ##
##   de DSM (Synology) pour faire fonctionner les notifications Websocket                     ##
##   Doc. vaultwarden :                                                                       ##
##        Route the /notifications/hub endpoint to the WebSocket server, by default           ##
##        at port 3012, making sure to pass the Connection and Upgrade headers.               ##
##        (Note the port can be changed with WEBSOCKET_PORT variable)                         ##
##        https://github.com/dani-garcia/vaultwarden/wiki/Enabling-WebSocket-notifications    ##
##                                                                                            ##
##==============================================================================================
##                                                                                            ##
##                             Principe de Tâche planifier à créer                            ##
##                                                                                            ##
## Il faut lancer régulièrement le script car toutes modifications faites dans l'interface    ##
## graphique du Reverse-Proxy de DSM va modifier le fichier de configuration. Il en va de     ##
## même lorsque le NAS redémarre.                                                             ##
##                                                                                            ##
##==============================================================================================
##                                                                                            ##
##        /!\    Il faut modifier l'adresse IP en ligne 58 par l'IP du NAS    /!\             ##
##                                                                                            ##
##==============================================================================================
##                                                                                            ##
## Paramètres de lancement du script :                                                        ##
## bash /volume1/docker/bitwarden/enable_ws.sh vault.example.com 5555 5556                    ##
##                                                                                            ##
## -- vault.example.com = Nom de domaine de vaultwarden (celui du Reverse Proxy de DSM)       ##
## -- 5555 = Port exposé ROCKET_PORT par Docker (Identique à celui du Reverse Proxy de DSM)   ##
## -- 5556 = Port exposé WEBSOCKET_PORT par Docker                                            ##
##                                                                                            ##
##==============================================================================================

LOC_DIR="/etc/nginx"
part1=0
part2=0
# declare -r nb_param=$#                           # Nombre d'argument(s) fourni(s) au script.
# declare -r param_1="$1"                          # 1er argument fourni
# declare -r param_2="$2"                          # 1er argument fourni
# declare -r param_3="$3"                          # 1er argument fourni
MY_DOMAIN=$1
PORT_ACCES=$2
PORT_CONT=$3
IP_NAS="192.168.2.200"
# Ici, spécifier la version de DSM
#   - 6 pour DSM 6.2.x
#   - 7 pour DSM 7.x (testé avec 7.0, 7.1, et 7.2)
# DSM=7
# La version de DSM est déterminée plus bas par le script.

script_name=$(basename "$0")

echo -e "\n$(date "+%R:%S - ") Script $script_name pour activer les Notifications Websockets"

f_affiche_parametre() {
    echo "          bash /volume4/docker/_Scripts-DOCKER/$script_name vault.example.com 5555 5556 "
    echo "                           -- vault.example.com = Nom de domaine de vaultwarden (celui du Reverse Proxy de DSM) "
    echo "                           -- 5555 = Port exposé ROCKET_PORT par Docker (Identique à celui du Reverse Proxy de DSM)"
    echo "                           -- 5556 = Port exposé WEBSOCKET_PORT par Docker"
    echo
    echo "La commande que tu dois lancer c'est : ./$script_name vault.example.com 5555 5556"
    echo
}

if [ ! $# -eq 3 ]; then
    if [ $# -eq 0 ]; then
        # Aucun paramètre n'a été fourni. On va afficher la liste de ce qui peut être utilisé.
        echo "$(date "+%R:%S - ") Aucun paramètre fourni ! Revoir l'appel du script :"
        f_affiche_parametre
    else
        echo "$(date "+%R:%S - ") Le nombre de paramètres fournis n'est pas correct ! Revoir l'appel du script :"
        f_affiche_parametre
    fi
    echo -e "$(date "+%R:%S - ") ECHEC de lancement du script !!!!!!!!!\n"
    exit 1
fi

echo "$(date "+%R:%S - ") Exécution des commandes..."
DSM=$(grep "majorversion" /etc.defaults/VERSION | awk -F "\"" '{print $2}')
echo "$(date "+%R:%S - ")    -- Version de DSM déterminée : $DSM"

#############################################################################################################
## Début de la partie de création/modification de fichiers
##
if [ -f $LOC_DIR/websocket.locations.vaultwarden ]; then
    rm $LOC_DIR/websocket.locations.vaultwarden
    part1=1
fi
echo """
location /notifications/hub/negotiate {
    proxy_http_version 1.1;
    proxy_set_header \"Connection\" \"\";
    
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_pass http://$IP_NAS:$PORT_ACCES;
}

location /notifications/hub {
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \"upgrade\";

    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header Forwarded \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_pass http://$IP_NAS:$PORT_CONT;
}

location /admin {
    # See: https://docs.nginx.com/nginx/admin-guide/security-controls/configuring-http-basic-authentication/
    # auth_basic "Private";
    # auth_basic_user_file /path/to/htpasswd_file;

    # For my Synology DSM, I created an Access Control Profiles to restrict access only to LAN and VPN IP adresses
    # This Access Control Profile is a file in the /etc/nginx/conf.d folder
    #include conf.d/.acl.8210faa5-6e80-40c3-9b29-38711430319d.conf*;
    allow 192.168.2.0/24;
    allow 192.168.10.0/24;
    allow 192.168.11.0/24;
    deny all;

    proxy_http_version 1.1;
    proxy_set_header \"Connection\" \"\";

    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_pass http://$IP_NAS:$PORT_ACCES/admin;
}
""" >>$LOC_DIR/websocket.locations.vaultwarden

# Note : avec DSM7, le chemin d'accès du fichier server.ReverseProxy.conf a changé
#         DSM6.2    = /etc/nginx/app.d/server.ReverseProxy.conf
#         DSM7.x    = /etc/nginx/sites-enabled/server.ReverseProxy.conf

if [ $DSM -eq 6 ]; then
    # Commandes fonctionnelles avec DSM6.2.x, mais plus avec DSM 7.0 (RC)
    ReverseProxyCONF="/etc/nginx/app.d/server.ReverseProxy.conf"

    if ! grep -q "websocket.locations.vaultwarden" /etc/nginx/app.d/server.ReverseProxy.conf; then
        sed -i "/$1;/ a\ include $LOC_DIR/websocket.locations.vaultwarden;" /etc/nginx/app.d/server.ReverseProxy.conf
        if nginx -t 2>/dev/null; then synoservicecfg --reload nginx; else exit 1; fi
        part2=1 # Variable pour indiquer que cette partie a été exécutée
    fi
elif [ $DSM -eq 7 ]; then
    # Commande fonctionnelles avec DSM 7, DSM 7.1 et DSM 7.2
    ReverseProxyCONF="/etc/nginx/sites-enabled/server.ReverseProxy.conf"

    if ! grep -q "websocket.locations.vaultwarden" /etc/nginx/sites-enabled/server.ReverseProxy.conf; then
        # Commande fonctionnelles avec DSM 7, DSM 7.1 et DSM 7.2
        sed -r "s#^([[:blank:]]*server_name[[:blank:]]*${MY_DOMAIN}[[:blank:]]*;[[:blank:]]*)\$#\1\n\n\t\tinclude ${LOC_DIR}/websocket.locations.vaultwarden;#" /etc/nginx/sites-enabled/server.ReverseProxy.conf >/etc/nginx/sites-enabled/server.ReverseProxy.conf.new
        mv /etc/nginx/sites-enabled/server.ReverseProxy.conf.new /etc/nginx/sites-enabled/server.ReverseProxy.conf

        #########################################################################################
        # Différents essais avant de trouver la bonne commande...
        #sed -i "/$VAR_RECHERCHE;/ a\ $VAR_AJOUT" /etc/nginx/sites-enabled/server.ReverseProxy.conf
        #sed -ir "s#(${VAR_RECHERCHE})#\1\n${VAR_AJOUT}#" mon fichier
        #sed -ir "s#(^[[:blank:]]*server_name[[:blank:]]*${MY_DOMAIN}[[:blank:]]*;[[:blank:]]*$)#\1\ninclude ${LOC_DIR}/websocket.locations.vaultwarden;\n#" /etc/nginx/sites-enabled/server.ReverseProxy.conf
        #sed -ir "s#^([[:blank:]]*server_name[[:blank:]]*${MY_DOMAIN}[[:blank:]]*;[[:blank:]]*)$#\1\ninclude ${LOC_DIR}/websocket.locations.vaultwarden;\n#" /etc/nginx/sites-enabled/server.ReverseProxy.conf
        #sed -ir "s#^([[:blank:]]*server_name[[:blank:]]*${MY_DOMAIN}[[:blank:]]*;[[:blank:]]*)\$#\1\n\tinclude ${LOC_DIR}/websocket.locations.vaultwarden;\n#" /etc/nginx/sites-enabled/server.ReverseProxy.conf
        #########################################################################################

        if nginx -t 2>/dev/null; then synosystemctl reload nginx; else exit 1; fi

        part2=1 # Variable pour indiquer que cette partie a été exécutée
    fi
else
    echo "$(date "+%R:%S - ")    -- !!!!!! --->  La version de DSM spécifiée dans le script n'est pas correcte. Vérifier le script !"
    exit 1
fi
##
## Fin de la partie de création/modification de fichiers
#############################################################################################################

if [ $part1 -eq 1 ]; then
    echo "$(date "+%R:%S - ")    -- Le fichier $LOC_DIR/websocket.locations.vaultwarden existait déjà, il a été supprimé puis recréé."
    echo "$(date "+%R:%S - ")    -- On relance nginx."
    if [ $DSM -eq 6 ]; then
        if nginx -t 2>/dev/null; then synoservicecfg --reload nginx; else exit 1; fi
    elif [ $DSM -eq 7 ]; then
        if nginx -t 2>/dev/null; then synosystemctl reload nginx; else exit 1; fi
    fi

else
    echo "$(date "+%R:%S - ")    -- Le fichier $LOC_DIR/websocket.locations.vaultwarden n'existait pas, il a été créé."
fi
if [ $part2 -eq 1 ]; then
    echo "$(date "+%R:%S - ")    -- !!!!!! --->  La modification dans le fichier $ReverseProxyCONF n'existait pas. Elle a été écrite."
    echo "$(date "+%R:%S - ")    -- !!!!!! --->  Le fichier $ReverseProxyCONF a du être réinitialisé après un reboot ou lors d'une modification du reverse-proxy dans DSM."
else
    echo "$(date "+%R:%S - ")    -- La modification du fichier $ReverseProxyCONF a déjà été effectuée lors d'une précédente exécution. Aucune modification n'est donc nécessaire."
fi

echo "$(date "+%R:%S - ") Script vaultwarden__Enable_Websocket_DSM6.sh terminé"

exit
