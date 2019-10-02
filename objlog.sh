#!/bin/bash
set -e

# 1. Get the stream id
objLogStreamId=$(oci streaming admin stream list \
    --compartment-id $TS_COMPART_ID \
    --name ObjLog \
    | jq -r '.data[].id' \
    )

# 2. Create a cursor to read the stream
cursorId=$(oci streaming stream cursor \
     create-cursor \
    --stream-id $objLogStreamId \
    --type AT_TIME \
    --partition 0 \
    --time "$(date --date='-1 hour' --rfc-3339=seconds)" \
    | jq -r '.data.value' \
    )

# 3. Read the stream and print useful info:
tabData=""
tabData+="eventType\teventTime\tresourceName\n"

for evtVal in $(oci streaming stream message get \
    --stream-id $objLogStreamId \
    --cursor $cursorId \
    | jq -r 'select(.data != null) | .data[].value' \
    )
do
    evtJson=$(echo $evtVal | base64 -d)

    evtType=$(echo $evtJson | jq -r '.eventType')
    evtTime=$(echo $evtJson | jq -r '.eventTime')
    resourceName=$(echo $evtJson | jq -r '.data.resourceName')

    # \n in the line data wasn't being observed so added in after whoe line is
    # generated
    line=$(printf "%s\t%s\t%s" "$evtType" "$evtTime" "$resourceName")
    tabData+="$line\n"

done

printf "$tabData" | column -t
