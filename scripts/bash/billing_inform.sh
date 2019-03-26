# by Ivanov Aleksey. 
# This script gets json from mongo db. Parse it, and send notifications based on this parsing.
# Requirements: mongo client; jq; sendmail;
#!/bin/bash

# Creating Json, consist of VMs with an appropriate end date of usage.

DB='dbname'
DBHOST='127.0.0.1'
DBPORT='27017'
JSON='billing.json'
CURDATE=$(date +%s)
MONTHLATER=$(date -d "+30 days" +%s)
OUTPUT='./letters/list.txt'
RECIPIENT='recipients.txt'
RECIPIENT_SORTED="sorted_recipients.txt"
PERSONAL_MAIL='./letters/mail_to_'
echo "[" > $JSON

mongo $DB --host $DBHOST --port $DBPORT --quiet --eval \
	"db.virt_mach.find({ "\$and": [{'last_end_date':{\$ne:'end_date_n/a'}},{'last_end_date':{\$ne: 'вечно'}}]}, \
	{"last_end_date": 1,"last_host":1,"last_vm_name":1,"last_owner":1,"_id":0}).forEach(printjson);" \
>> $JSON
 
sed -i 's/}/},/g' $JSON
sed -i '$ s/.$//' $JSON
echo "]" >> $JSON

ARRAYLENGHT=$(expr $(cat $JSON | jq length) - 1)

#Create recipient list

echo "$(cat $JSON | jq -r ".[0].last_owner")" > $RECIPIENT

for i in $( seq 1 $ARRAYLENGHT )
do
    echo $(cat $JSON | jq -r ".[$i].last_owner") >> $RECIPIENT
done

cat $RECIPIENT | sort | uniq | sed '/admin_n/d' > $RECIPIENT_SORTED 

#Creating and sending personal email

while read email; do

    echo "from: billing" > $PERSONAL_MAIL$email
    echo "Subject: Some subject" >> $PERSONAL_MAIL$email
    echo "Content-Type: text/plain; charset=UTF-8" >> $PERSONAL_MAIL$email
    echo "some text" >> $PERSONAL_MAIL$email
    echo "some text" >> $PERSONAL_MAIL$email
    echo "" >> $PERSONAL_MAIL$email
    echo "some text" >> $PERSONAL_MAIL$email
    echo "some text:" >> $PERSONAL_MAIL$email
    cat $JSON | jq -c "[ .[] | select( .last_owner | contains(\"$email\")) ]" | jq -r '.[]| "\(.last_end_date) \(.last_host) \(.last_vm_name)"' >> $PERSONAL_MAIL$email 

    sendmail $email < $PERSONAL_MAIL$email

done < $RECIPIENT_SORTED

# Creating LIST.txt of all already expired VM

echo "from: billing" > $OUTPUT
echo "Subject: Some subject" >> $OUTPUT
echo "Content-Type: text/plain; charset=UTF-8" >> $OUTPUT
echo "some text" >> $OUTPUT 
echo "" >> $OUTPUT

for i in $( seq 0 $ARRAYLENGHT ) 
do

    VMDATE=$(date -d $(cat $JSON | jq -r ".[$i].last_end_date" | awk -F "." '{print $3$2$1}') +%s)
    
    if [ $VMDATE -lt $CURDATE ];
    then
	    echo $(cat $JSON | jq -r ".[$i].last_end_date, .[$i].last_vm_name, .[$i].last_owner") | sed 's/ /,/g' >> $OUTPUT
    fi


done

# Creating LIST.txt of all VM going to expire in one mounth

echo "" >> $OUTPUT
echo "some text" >> $OUTPUT
echo "" >> $OUTPUT

for i in $( seq 0 $ARRAYLENGHT )
do

    VMDATE=$(date -d $(cat $JSON | jq -r ".[$i].last_end_date" | awk -F "." '{print $3$2$1}') +%s)

    if [ $VMDATE -gt $CURDATE ] && [ $VMDATE -lt $MONTHLATER ];
    then
            echo $(cat $JSON | jq -r ".[$i].last_end_date, .[$i].last_vm_name, .[$i].last_owner") | sed 's/ /,/g' >> $OUTPUT
    fi


done

# Sending mail to global admin

sendmail admin@mail.mail < $OUTPUT