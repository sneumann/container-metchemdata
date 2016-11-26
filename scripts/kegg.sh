######
# kegg filler script
######

# write a single kegg entry as postgres query
write_kegg_entry () {
 line=$1
 line=$(echo $line | sed "s/'/''/g")
 library_id=$2
 outfile=$3
 # read values from argument string
 IFS='|' read -a vals <<< "$line"
 # insert kegg entry
 echo "WITH ins_compound AS (
     INSERT INTO compound(monoisotopic_mass, molecular_formula, smiles, inchi, inchi_key_1, inchi_key_2, inchi_key_3)
     VALUES ('${vals[1]}', '${vals[2]}', '${vals[3]}', '${vals[4]}', '${vals[5]}', '${vals[6]}', '${vals[7]}') on conflict (inchi_key_1,inchi_key_2,inchi_key_3) do update set monoisotopic_mass='${vals[1]}', molecular_formula='${vals[2]}', smiles='${vals[3]}', inchi='${vals[4]}', inchi_key_1='${vals[5]}', inchi_key_2='${vals[6]}', inchi_key_3='${vals[7]}'
      RETURNING compound_id
    )
 , ins_substance AS (
     INSERT INTO substance (library_id, compound_id, accession)
     SELECT '$library_id', compound_id, '${vals[0]}'
     FROM   ins_compound
     on conflict (accession) do update set compound_id=substance.compound_id
     RETURNING substance_id
 )
 INSERT INTO name (name, substance_id)
 SELECT '${vals[8]}', substance_id
 FROM ins_substance on conflict (substance_id) do update set name=name.name;" >> $outfile
}

# deletes from substance table NOT from compound table
delete_kegg_entries () {
 filename=$1
 library_id=$2
 # get accession ranges from filename
 IFS=' ' read -a ranges <<< "$(echo $filename | sed "s/.*_C0*\([0-9]*\)_C0*\([0-9]*\)/\1 \2/")"
 # get accessions not included anymore
 # this is performed by comparison 
 comm -23 <(for (( c=${ranges[0]}; c<=${ranges[1]}; c++ )); do echo 0000$c | sed "s/.*\(.....$\)/C\1/"; done | sort) <(cut -d"|" -f1 /tmp/${filename}.sql | sort) > /tmp/${filename}.delete
 while read line
 do
   echo "delete from substance where accession='${line}' and library_id='${library_id}';" >> /tmp/${filename}.delete_query
 done < /tmp/${filename}.delete
 if [ -e /tmp/${filename}.delete_query ] 
 then
   # execute query file onto postgres server
   /usr/bin/psql -f /tmp/${filename}.delete_query -h $POSTGRES_IP -U $POSTGRES_USER -d $POSTGRES_DB
   rm /tmp/${filename}.delete_query
 fi
}


# includes adding new entries and deleting non-existsing ones
# deletes entries only from substance table as references from other databases might still
# be present
# another function could delete entries from compund table that aren't referenced anymore
update_kegg () {
 # check if database exists
 exists=$(/usr/bin/psql -c "select 1 from library where library_name='kegg';" -h $POSTGRES_IP -U $POSTGRES_USER -qtA -d $POSTGRES_DB)
 last_updated=$(/usr/bin/psql -c "SELECT last_updated FROM library where library_name='kegg';" -h $POSTGRES_IP -U $POSTGRES_USER -qtA -d $POSTGRES_DB)
 # get current modification date
 dbdatesecs=$(date -d $last_updated +%s)
 mostcurrentsecs=$dbdatesecs
 mostcurrent=""
 if [ ! "$exists" == 1 ]
 then 
   echo "library kegg does not exist"
   exit 1
 fi
 library_id=$(/usr/bin/psql -c "SELECT library_id FROM library where library_name='kegg';" -h $POSTGRES_IP -U $POSTGRES_USER -qtA -d $POSTGRES_DB)
 if [ ! -e /data/${KEGG_MIRROR} ]
 then
   echo "/data/${KEGG_MIRROR} not found"
   return 1       
 fi
 # loop to check each data file
 unset IFS
 for i in $(ls /data/${KEGG_MIRROR})
 do
  echo "file $i"
  # check time stamp of file and database 
  filedatesecs=$(date -r /data/${KEGG_MIRROR}/$i +%s)
  filedate=$(date -r /data/${KEGG_MIRROR}/$i +%Y-%m-%d)
  if [ $dbdatesecs -ge $filedatesecs ]
  then
      break
  fi  
  if [ $filedatesecs -gt $mostcurrentsecs ]
  then
      mostcurrentsecs=$filedatesecs
      mostcurrent=$filedate
  fi  
  # get filename
  filename=$(echo $i | sed 's/\.csv\.gz//')
  # unzip file
  gunzip -c -k /data/$KEGG_MIRROR/$i > /tmp/${filename}.csv
  # write out values of specific columns
  paste -d"|" \
  <(awk -F '[|]' -v c="" 'NR==1{for(i=1;i<=NF;i++)n=$i~"identifier$"?i:n;next}n{print $n}' /tmp/${filename}.csv) \
  <(awk -F '[|]' -v c="" 'NR==1{for(i=1;i<=NF;i++)n=$i~"monoisotopicmass$"?i:n;next}n{print $n}' /tmp/${filename}.csv) \
  <(awk -F '[|]' -v c="" 'NR==1{for(i=1;i<=NF;i++)n=$i~"molecularformula$"?i:n;next}n{print $n}' /tmp/${filename}.csv) \
  <(awk -F '[|]' -v c="" 'NR==1{for(i=1;i<=NF;i++)n=$i~"smiles$"?i:n;next}n{print $n}' /tmp/${filename}.csv) \
  <(awk -F '[|]' -v c="" 'NR==1{for(i=1;i<=NF;i++)n=$i~"inchi$"?i:n;next}n{print $n}' /tmp/${filename}.csv) \
  <(awk -F '[|]' -v c="" 'NR==1{for(i=1;i<=NF;i++)n=$i~"inchikey1$"?i:n;next}n{print $n}' /tmp/${filename}.csv) \
  <(awk -F '[|]' -v c="" 'NR==1{for(i=1;i<=NF;i++)n=$i~"inchikey2$"?i:n;next}n{print $n}' /tmp/${filename}.csv) \
  <(awk -F '[|]' -v c="" 'NR==1{for(i=1;i<=NF;i++)n=$i~"inchikey3$"?i:n;next}n{print $n}' /tmp/${filename}.csv) \
  <(awk -F '[|]' -v c="" 'NR==1{for(i=1;i<=NF;i++)n=$i~"name$"?i:n;next}n{print $n}' /tmp/${filename}.csv) \
  > /tmp/${filename}.sql
  # write all insert commands into one query file
  IFS=''
  while read line
  do
   # writes single insert command to query file
   write_kegg_entry "$line" "$library_id" "/tmp/${filename}.insert_query"
  done < /tmp/${filename}.sql
  # check if insert query file was generated
  if [ -e /tmp/${filename}.insert_query ] 
  then
    # execute query file onto postgres server
    /usr/bin/psql -f /tmp/${filename}.insert_query -h $POSTGRES_IP -U $POSTGRES_USER -d $POSTGRES_DB
    rm /tmp/${filename}.insert_query
  fi
  # delete non reference entries
  delete_kegg_entries $filename $library_id
 done
 # update library modification date
 /usr/bin/psql -c "update library set last_updated='$mostcurrent' where library_id='$library_id';" -h $POSTGRES_IP -U $POSTGRES_USER -qtA -d $POSTGRES_DB
}