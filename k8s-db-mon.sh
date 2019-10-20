contextCount="$(cat siteinfo.json | jq '.k8sdbs | length')"
for (( u = 0; u < $contextCount; u++ ));
do
  export CONTEXT=$(cat siteinfo.json | jq -r .k8sdbs[$u].context)
  setContext=$(kubectl config use-context $CONTEXT)
  echo $setContext
  echo "Cluster Context: $CONTEXT"
  echo "--------------------------|"
  export infoCount="$(cat siteinfo.json | jq --argjson count "$u" '.k8sdbs[$count].info | length')"

  for (( k = 0; k < $infoCount; k++ ));
  do
    export SERVICE=$(cat siteinfo.json | jq -r .k8sdbs[$u].info[$k].service)
    echo " Service: $SERVICE"
    export innerArrayCount="$(cat siteinfo.json | jq --argjson context "$u" --argjson info "$k" '.k8sdbs[$context].info[$info].db | length')"

    for (( j = 0; j < $innerArrayCount; j++ ));
    do
      export DBNAME=$(cat siteinfo.json | jq -r .k8sdbs[$u].info[$k].db[$j].name)
      export certCount="$(cat siteinfo.json | jq --argjson context "$u" --argjson info "$k" --argjson db "$j" '.k8sdbs[$context].info[$info].db[$db].certs | length')"
      echo " - In $DBNAME..."

      for (( p = 0; p < $certCount; p++ ));
      do
        export DBCERT=$(cat siteinfo.json | jq -r .k8sdbs[$u].info[$k].db[$j].certs[$p])
        echo "   Checking $DBCERT"
        output=$(kubectl get secret -n $SERVICE $DBNAME -o json | jq --arg cert $DBCERT -r '.data[$cert]' | base64 -D |\
          openssl x509 -noout -dates | grep notAfter | sed -e 's#notAfter=##' | sed -e 's/GMT//g' | sed -e 's/ $//g')
        issuer=$(kubectl get secret -n $SERVICE $DBNAME -o json | jq --arg cert $DBCERT -r '.data[$cert]' | base64 -D |\
          openssl x509 -noout -issuer | grep CN | sed -e 's/.*CN=\(.*\)/\1/g')

        end_epoch=$(date -j -f '%b %d %T %Y' "$output" +%s)
        current_epoch=$(date +%s)
        secs_to_expire=$(($end_epoch - $current_epoch))
        days_to_expire=$(($secs_to_expire / 86400))
        gracedays=30
        danger_close=14
        comp_val=-17000

        echo " - Days to expire: $days_to_expire"
        if test "$days_to_expire" -lt "$danger_close";
          then
            export warning_color="#fe0000"
          else
            export warning_color="#fce903"
        fi

        if test "$days_to_expire" -lt "$gracedays";
          then
            echo "    - WARNING: The $DBCERT cert for $SERVICE will expire soon!"
            touch $SERVICE-expiring.txt
          else
            echo "    - This certificate does not expire soon."
        fi

        if [[ -f $SERVICE-expiring.txt ]];
          then
            if [[ "$days_to_expire" -lt "$comp_val" ]]
              then
                cat slack_payload.json | jq -cr ".attachments[0].color = \"$warning_color\"" | jq -cr ".attachments[0].blocks[0].text.text = \"*Service:* $SERVICE\n *DB Name:* $DBNAME\n *Cert:* $DBCERT\n *Issuer:* $issuer\"" | jq -cr ".text = \"*<https://<your-bamboo-url>/browse/${bamboo.buildKey}|Certificate expires in $days_to_expire days!>*\"" | jq -c . > slack.json
                curl -X POST -H 'Content-type: application/json' --data '@slack.json' https://hooks.slack.com/services/<your-slack-hook>
                rm -rf $SERVICE-expiring.txt
              else
                cat slack_payload.json | jq -cr ".attachments[0].color = \"$warning_color\"" | jq -cr ".attachments[0].blocks[0].text.text = \"*Service:* $SERVICE\n *DB Name:* $DBNAME\n *Cert:* $DBCERT\n *Issuer:* $issuer\"" | jq -cr ".text = \"*<https://<your-bamboo-url>/browse/${bamboo.buildKey}|ERROR: Could not connect to certificate!>*\"" | jq -c . > slack.json
                curl -X POST -H 'Content-type: application/json' --data '@slack.json' https://hooks.slack.com/services/<your-slack-hook>
                rm -rf $SERVICE-expiring.txt
            fi
          else
            echo "     - No message will be posted to Slack."
        fi
      done
    done
    echo ""
  done
done