#!/bin/bash
#
#	Automação Servidor DNS
#
#
#CVS $Header$

shopt -o -s nounset

menu(){
	echo "-----------------------------------"
	echo -e "Scrip Automático de Instalação\n"
	echo -e "1. Configuração de IP estático\n"
	echo -e "2. Configuração do Sources List\n"
	echo -e "3. DNS\n"
	echo -e "4. WEB\n"
	echo -e "5. Sair\n"
	echo "Selecione a opção desejada: "
	read option

	case "$option" in
	1)
		#echo "escolheu 1"
		ipFixo
	;;
	2)
		#echo "escolheu 2"
		echo -e "deb http://deb.debian.org/debian/ buster main non-free contrib\ndeb-src http://deb.debian.org/debian/ buster main non-free contrib" > "/etc/apt/sources.list"
	;;
	3)
		dns
	;;
	4)
		web
	;;
	5)
		echo "Saindo..."
		echo "Obrigado, volte sempre!!!"
		sleep 3
		exit 1
	;;
	esac
}

web(){
	server_root="/var/www/html"
	server_port="80"
	index_page="index.html"

	# Fazer a atualização dos pacotes do sistema
	echo "Atualizando pacotes do sistemas (apt-get)"
	apt-get update -y && apt-get upgrade -y
	sleep 4

	# Validar a existência dos pacotes necessários para a execução do servidor
	if ! command -v apache2;then
	        echo "O servidor Apache2 não está instalado"
	        echo "Instalando o Servidor..."

	        apt-get install apache2 -y
	        sleep 4
	else
	         echo "O servidor Apache2 já está instalado!"
	fi

	# Validar se o dirétório existe
	if [[ ! -d "$server_root" ]]; then
	        echo "Criando diretório do Servidor"
	        mkdir -p "$server_root"
	fi

	# Validar arquivo index.html
	if [[ ! "$server_root/$index_page" ]]; then
	        echo "Criando a página inicial..."
	        sleep 1
	        echo "<html><body><h1>Bem-vindo ao servidor web default!! TESTE</h1></body></html>" > "$server_root/$index_page"
	        sleep 3
	fi

	# Inicializando o servidor Apache2
	echo "-------------------------------"
	echo "Iniciando o servidor Apache2"
	echo "Diretório do site: $server_root"
	echo "Porta: $server_port"
	sleep 3
}

dns(){
	while true
	do
	echo "-----------------------------------"
	echo -e "Scrip Auto DNS\n"
	echo -e "1. Instalar\n"
	echo -e "2. Desinstalar\n"
	echo -e "3. Iniciar\n"
	echo -e "4. Parar\n"
	echo -e "5. Criar\n"
	echo -e "6. Editar\n"
	echo -e "7. Status\n"
	echo -e "8. Sair\n"
	echo "Selecione a opção desejada: "
	read option

	case "$option" in
	1)
		#echo "escolheu 1"
		instalarDns
	;;
	2)
		#echo "escolheu 2"
		apt-get remove --purge bind9 -y && apt-get autoremove -y
		rm -r /etc/bind
	;;
	3)
		#echo "escolheu 3"
		systemctl start bind9 && systemctl status bind9
		sleep 4
	;;
	4)
		#echo "escolheu 4"
		systemctl stop bind9 && systemctl status bind9
		sleep 4
	;;
	5)
		#echo "escolheu 5"
		criarDns
	;;
	6)
		#echo "escolheu 6"
		editarDns
	;;
	7)
		#echo "escolheu 7"
		systemctl status bind9
		sleep 4
	;;
	8)
		#echo "escolheu 8"
		echo "Saindo..."
		echo "Obrigado, volte sempre!!!"
		sleep 3
		exit 1
	;;
	*)
		echo "Opção inválida!"
	;;
	esac
	done
}

ipFixo(){
	echo "O IP que este servidor DNS terá:*"
	read ip_fixo
	echo "A sua máscara de rede:*"
	read mask_fixo
	echo "o seu gateway:"
	read gateway
	echo "A interface em que o DNS funcionará:*"
	read interface

	# Configurando IP estático
	{
	if [[ "$gateway" == "0" ]]; then
		sed -i "s|iface $interface inet dhcp|iface $interface inet static \naddress $ip_fixo \nnetmask $mask_fixo|" "/etc/network/interfaces"
	else
		sed -i "s|iface $interface inet dhcp|iface $interface inet static \naddress $ip_fixo \nnetmask $mask_fixo \ngateway $gateway|" "/etc/network/interfaces"
	fi
	} >>"/etc/network/interfaces"
}

instalarDns(){
	conf_default="/etc/bind/named.conf.default-zones"
	dir_dns="/etc/bind"

	# Atualizando pacotes
	apt-get update -y && apt-get upgrade -y
	sleep 3

	# Verificando se o serviço dhcp já existe
	if [ ! -e "$dir_dns/db.empty" ]; then
		echo "O servidor DNS não está instalado"
		echo "Instalando servidor..."
		sleep 3
		apt-get install bind9 -y
		sleep 2
	else
		echo "O servidor DNS já está instalado!!!"
		sleep 3
		exit 1
	fi

	# Configurando
	echo "---------------------------------------------------"
	echo "Hora de configurar o Servidor!!"
	echo "É necessário que algumas informações sejam passadas"
	echo "---------------------------------------------------"
	echo "* - Obrigatório informar algo"
	echo "Se preferir não informar coloque - 0"
	echo "---------------------------------------------------"
	echo "Ip fixo deste servidor DNS:"
	read ip_fixo

	# Criando zonas e as configurando
	while true; do
		echo "Zona que deseja colocar:*"
		read zone
		echo "Final da zona que deseja colocar:* (.local, .com, ...)"
		read end
		# Configurando zona no named.conf.default-zones
		zona_completa="$zone$end"
		zona_local="$dir_dns/db.$zone"
		{
		echo "zone @" {
		echo "      type master;"
		echo "      file =;"
		echo -e "};\n"

		sed -i 's/@/"x"/g' $conf_default
		sed -i "s|x|$zona_completa|g" $conf_default
		sed -i 's/=/"+"/g' $conf_default
		sed -i "s|+|$zona_local|g" $conf_default

		} >>"$conf_default"

		echo "Início da zona que seja colocar:* (www, ns1, ...)"
		read start
		echo "Ip do serviço associado a esse início da zona:* "
		read ip_service

		# Criando db. e configurando
		localhost="ns1.$zone"
		touch "$zona_local"
		{
		echo -e "; BIND reverse data file for empty rfc1918 zone\n;\n; DO NOT EDIT THIS FILE - it is used for multiple zones.\n; Instead, copy it, edit named.conf, and use that copy.\n;\n=TTL	86400\n@	IN	SOA	localhost. root.localhost. (\n			      1		; Serial\n			 604800		; Refresh\n			  86400		; Retry\n			2419200		; Expire\n			  86400 )	; Negative Cache TTL\n;\n@	IN	NS	localhost."
		echo "$start	IN	A	$ip_service"
		sed -i "s|=|$|" "$dir_dns/db.$zone"
		sed -i "s|localhost|$localhost|g" "$dir_dns/db.$zone"
		} >>"$dir_dns/db.$zone"

		echo "Deseja adicionar mais um início de zona? (S / N)"
		read verificar
		while [[ "$verificar" == "S" || "$verificar" == "s" ]]; do
			echo "Início da zona que seja colocar:* (www, ns1, ...)"
			read start
			echo "Ip do serviço associado a esse início da zona:* "
			read ip_service
			{
			echo "$start	IN	A	$ip_service"
			} >>"$dir_dns/db.$zone"

			echo "Deseja adicionar mais um início de zona? (S / N)"
			read verificar
		done

		echo "Deseja adicionar mais uma zona? (S / N)"
		read verificar
		if [[ "$verificar" == "N" || "$verificar" == "n" ]]; then
			break
		fi
	done

	# Configurando o resolv.conf
	if [[ ! "$ip_fixo" == "0" ]]; then
		rm "/etc/resolv.conf"
		touch "/etc/resolv.conf"
		{
		echo "nameserver $ip_fixo"
		} >>"/etc/resolv.conf"
	fi

	echo "----------------------------------------------------------------------"
	echo "Configuração realizada com sucesso!!!"
	echo "----------------------------------------------------------------------"
	sleep 3
}

criarDns(){
	conf_default="/etc/bind/named.conf.default-zones"
	dir_dns="/etc/bind"

	echo "--------------------------------------------------------"
	echo -e "O que deseja criar?\n"
	echo -e "1. Criar uma zona nova e a configura-la\n"
	echo "--------------------------------------------------------"
	read option

	case "$option" in
	1)
		while true; do
		echo "Zona que deseja colocar:*"
		read zone
		echo "Final da zona que deseja colocar:* (.local, .com, ...)"
		read end
		# Configurando zona no named.conf.default-zones
		zona_completa="$zone$end"
		zona_local="$dir_dns/db.$zone"
		{
		echo "zone @" {
		echo "      type master;"
		echo "      file =;"
		echo -e "};\n"

		sed -i 's/@/"x"/g' $conf_default
		sed -i "s|x|$zona_completa|g" $conf_default
		sed -i 's/=/"+"/g' $conf_default
		sed -i "s|+|$zona_local|g" $conf_default

		} >>"$conf_default"

		echo "Início da zona que seja colocar:* (www, ns1, ...)"
		read start
		echo "Ip do serviço associado a esse início da zona:* "
		read ip_service

		# Criando db. e configurando
		localhost="ns1.$zone"
		touch "$zona_local"
		{
		echo -e "; BIND reverse data file for empty rfc1918 zone\n;\n; DO NOT EDIT THIS FILE - it is used for multiple zones.\n; Instead, copy it, edit named.conf, and use that copy.\n;\n=TTL	86400\n@	IN	SOA	localhost. root.localhost. (\n			      1		; Serial\n			 604800		; Refresh\n			  86400		; Retry\n			2419200		; Expire\n			  86400 )	; Negative Cache TTL\n;\n@	IN	NS	localhost."
		echo "$start	IN	A	$ip_service"
		sed -i "s|=|$|" "$dir_dns/db.$zone"
		sed -i "s|localhost|$localhost|g" "$dir_dns/db.$zone"
		} >>"$dir_dns/db.$zone"

		echo "Deseja adicionar mais um início de zona? (S / N)"
		read verificar
		while [[ "$verificar" == "S" || "$verificar" == "s" ]]; do
			echo "Início da zona que seja colocar:* (www, ns1, ...)"
			read start
			echo "Ip do serviço associado a esse início da zona:* "
			read ip_service
			{
			echo "$start	IN	A	$ip_service"
			} >>"$dir_dns/db.$zone"

			echo "Deseja adicionar mais um início de zona? (S / N)"
			read verificar
		done

		echo "Deseja adicionar mais uma zona? (S / N)"
		read verificar
		if [[ "$verificar" == "N" || "$verificar" == "n" ]]; then
			break
		fi
	done
	;;
	esac
}

editarDns(){
	echo "--------------------------------------------------------"
	echo -e "O que deseja editar?\n"
	echo -e "1. Adicionar mais uma extenção a uma zona existente\n"
	echo "--------------------------------------------------------"
	read option

	case "$option" in
	1)
		echo "Qual o nome do domínio que deseja editar?"
		read zone
		echo "Extensão que deseja adicionar:* (www, ns1, ...)"
		read start
		echo "Ip do serviço associado a essa extensão:* "
		read ip_service
		{
		echo "$start	IN	A	$ip_service"
		} >>"/etc/bind/db.$zone"
	;;
	esac
}

# Validando permissão de super usuário
if [[ "EUID" -ne 0 ]]; then
	echo "Necessário estar em modo super usuário!"
	sleep 3
	exit 1
else
	menu
fi