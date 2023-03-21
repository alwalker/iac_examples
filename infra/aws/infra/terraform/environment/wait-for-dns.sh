while true
do
	echo "Querying A record for $ROOT_RECORD"

	ANSWER=$(host -t A $ROOT_RECORD)

	if [[ $? == 0 ]]; then
		break
	else
		sleep 10
		continue
	fi
done 