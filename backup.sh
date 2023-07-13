# !/bin/bash
######################################################
# Script de backup 
# versao: v1.7
# Ultima atualização: 13/07/2023
######################################################

. ./parametros.conf

DATA=`date +%H:%M_%d-%m-%Y`
ARQUIVO="BKP_${DATA}"
NOMESERVIDOR=`hostname -s`
ARQ_SAIDA="/script/log/bkp_${DATA}.log"

function envia() {
  ASSUNTO="${1}"
  ARQSAIDA="${2}"
  DST_MAILS="${3}"

  for i in ${DST_MAILS}
  do
    cat "${ARQSAIDA}" | /usr/bin/nail -s "[${NOMESERVIDOR}] ${ASSUNTO}" "${i}"
  done
}

function timediff() {
  if [ $# -ne 2 ]; then
    echo "timediff '12/31/1999 8:45' '02/25/2000 23:52'"
  else
    echo -n "Tempo Total do backup = "  >> ${ARQ_SAIDA}
    datum_1=`date -d "$1" +%s`
    datum_2=`date -d "$2" +%s`
    let DIFF=$datum_2-$datum_1;
    if [ ${DIFF} -lt 0 ]; then
      let DIFF=DIFF*-1
    fi
    let PERC=${DIFF}/60;
    let ORA=${PERC}/60;
    let NAP=${ORA}/24;
    let ORA_DIFF=${ORA}-24*${NAP};
    let PERC_DIFF=${PERC}-60*${ORA}
    let MP_DIFF=${DIFF}-60*${PERC}
    if [ "${NAP}" != "0" ]; then
      echo "${NAP} dias, ${ORA_DIFF} horas ${PERC_DIFF} minutos ${MP_DIFF} segundos."
    else
      if [ "${ORA_DIFF}" != "0" ]; then
        echo "${ORA_DIFF} horas ${PERC_DIFF} minutos ${MP_DIFF} segundos."
      else
        if [ "${PERC_DIFF}" != "0" ]; then
          echo "${PERC_DIFF} minutos ${MP_DIFF} segundos."
        else
          echo "${MP_DIFF} segundos."
        fi
      fi
    fi
  fi
}


(
   INICIO="$(date '+%m/%d/%Y %H:%M')"
   echo "$(date '+%Y-%m-%d %H:%M') Inicio do backup ${DATA}"

########################################################################

   if [ ! -d "${BACKUP_DIR}/" ]; then
      echo "$(date '+%Y-%m-%d %H:%M') - Criando pasta ${BACKUP_DIR}"
      mkdir -p ${BACKUP_DIR}
      if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi
   fi

   echo "$(date '+%Y-%m-%d %H:%M') - Apagando tag"
   rm -Rf $BACKUP_DIR/B*

   echo "$(date '+%Y-%m-%d %H:%M') - Criando tag"
   touch $BACKUP_DIR/$ARQUIVO
   if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

   if [ ! -e "${BACKUP_DIR}/id" ]; then
      touch ${BACKUP_DIR}/id
      echo "1" > ${BACKUP_DIR}/id
   fi

   while read linha; do
      ID=${linha}
   done < ${BACKUP_DIR}/id
   if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi
   echo "$(date '+%Y-%m-%d %H:%M') - Indice do backup: ${ID}"

   LOG=`${AWS} s3 ls s3://${BUCKET}/servers/${NOMESERVIDOR}/${ID}/ |grep BKP|cut -d" " -f13`
   echo "$(date '+%Y-%m-%d %H:%M') - Apagando tag anterior: ${LOG}"
   ${AWS} s3 rm s3://${BUCKET}/servers/${NOMESERVIDOR}/${ID}/${LOG} --quiet
   if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

   echo "$(date '+%Y-%m-%d %H:%M') - Upload nova tag:       ${ARQUIVO}"
   ${AWS} s3 cp ${BACKUP_DIR}/${ARQUIVO} s3://${BUCKET}/servers/${NOMESERVIDOR}/${ID}/ --quiet
   if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

########################################################################

   if [ ${SITES} = 1 ]; then

      echo "$(date '+%Y-%m-%d %H:%M') - Listando Sites"
      ls ${DIR_SITES} > ${BACKUP_DIR}/aux
      if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi
      echo "$(cat ${BACKUP_DIR}/aux)"
      echo .

      while read PASTA; do
         if [ -e "${BACKUP_DIR}/www/${PASTA}.tar.gz" ] ; then
            echo "$(date '+%Y-%m-%d %H:%M')    ...excluindo"
            rm ${BACKUP_DIR}/${PASTA}.tar.gz
            if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi
         fi

         echo "$(date '+%Y-%m-%d %H:%M')    ...compactando (${PASTA})"
         tar -czf ${BACKUP_DIR}/${PASTA}.tar.gz ${DIR_SITES}/${PASTA}
         if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

         echo "$(date '+%Y-%m-%d %H:%M')    ...enviando"
         ${AWS} s3 cp ${BACKUP_DIR}/${PASTA}.tar.gz s3://${BUCKET}/servers/${NOMESERVIDOR}/${ID}/www/ --quiet
         if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

         echo "$(date '+%Y-%m-%d %H:%M')    ...limpando"
         rm ${BACKUP_DIR}/${PASTA}.tar.gz
         if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi
      done < ${BACKUP_DIR}/aux

      rm ${BACKUP_DIR}/aux

   fi

########################################################################
   if [ ${CONF} = 1 ]; then

      if [ -e "${BACKUP_DIR}/httpd_conf.tar.gz" ] ; then
         echo "$(date '+%Y-%m-%d %H:%M') - Upload nova tag:       ${ARQUIVO}"
         rm ${BACKUP_DIR}/httpd_conf.tar.gz
         if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi
      fi

      echo "$(date '+%Y-%m-%d %H:%M') - Compactando configuracoes: ${DIR_CONF}"
      tar -czf ${BACKUP_DIR}/httpd_conf.tar.gz ${DIR_CONF}
      if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

      echo "$(date '+%Y-%m-%d %H:%M') -    ...enviando"
      ${AWS} s3 cp ${BACKUP_DIR}/httpd_conf.tar.gz s3://${BUCKET}/servers/${NOMESERVIDOR}/${ID}/ --quiet
      if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

      echo "$(date '+%Y-%m-%d %H:%M') -    ...limpando"
      rm ${BACKUP_DIR}/httpd_conf.tar.gz
      if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

   fi

########################################################################

   if [ ${BANCOS} = 1 ]; then

      echo "$(date '+%Y-%m-%d %H:%M') - Listando Bancos:"
      databases=`${MYSQL} --user=${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`
      if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

      for db in ${databases}; do
         echo "$(date '+%Y-%m-%d %H:%M') - ${db}"
         if [ -e "${BACKUP_DIR}/sql/${db}.xz" ] ; then
            rm ${BACKUP_DIR}/sql/${db}.xz
            if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi
         fi

         echo "$(date '+%Y-%m-%d %H:%M')    ...compactando"
         ${MYSQLDUMP} --force --opt --user=${MYSQL_USER} -p${MYSQL_PASSWORD} --databases ${db} | xz -1 > ${BACKUP_DIR}/${db}.xz
         if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

         echo "$(date '+%Y-%m-%d %H:%M')    ...enviando"
         ${AWS} s3 cp ${BACKUP_DIR}/${db}.xz s3://${BUCKET}/servers/${NOMESERVIDOR}/${ID}/sql/ --quiet
         if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

         echo "$(date '+%Y-%m-%d %H:%M')    ...limpando"
         rm ${BACKUP_DIR}/${db}.xz
         if [ "$?" != 0 ]; then echo "$(date '+%Y-%m-%d %H:%M') - ERRO"; fi

      done

   fi

   FIM="$(date '+%m/%d/%Y %H:%M')"
   timediff "${INICIO}" "${FIM}"

########################################################################

   ID=$((${ID}+1))
   if [ ${ID} -gt ${RETENCAO} ]; then ID=1; fi

   echo `date` >>  $BACKUP_DIR/$ARQUIVO
   echo $ID > /backup/id

) 2>&1 | tee -a ${ARQ_SAIDA}

dos2unix ${ARQ_SAIDA}
ERRO=`cat ${ARQ_SAIDA}| grep -i erro |wc -l`

if [ ${ERRO} != "0" ]; then
   envia "ERRO de backup" "${ARQ_SAIDA}" "${MAILS}"
fi

