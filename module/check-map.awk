/^Number of camera devices:/ { six=($NF==6) }
/static information: ==/ { main=($0 ~ /\/vendor_qti\/2 \(/); inmap=0; pix=0 }
main && /android.scaler.availableStreamConfigurations \(/ { inmap=1; next }
main && /android.sensor.info.pixelArraySize \(/ { pix=1; next }
$0 !~ /^[[:space:]]*\[/ { inmap=0 }
main && pix { geometry=($1==(dual ? "[8192" : "[4096") && $2==(dual ? 6144 : 3072)); pix=0 }
main && inmap && $1=="[32" && $4=="OUTPUT" {
    if ($2==8192 && $3==6144) full=1
    if ($2==4096 && $3==3072) binned=1
}
END { exit !(six && geometry && binned && (dual ? full : !full)) }
