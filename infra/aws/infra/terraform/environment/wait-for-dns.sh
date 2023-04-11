while true
do
	echo "Querying name server: $NAME_SERVER for A record for $ROOT_RECORD"
	ANSWER=$(host -t A $ROOT_RECORD $NAME_SERVER)

	if [[ $? == 0 ]]; then
		break
	else
		sleep 10
		continue
	fi
done 