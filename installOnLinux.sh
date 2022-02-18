#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Gunakan akses root untuk jalankan file ini"
    exit
fi

export FORCE_UNSAFE_CONFIGURE=1

REPO_URL=https://github.com/coolsnowwolf/lede
REPO_BRANCH=master
rootDir=$PWD
hasilCompile=$rootDir/hasilCompile
openwrt="$hasilCompile/openwrt"
lokarmvirt=$hasilCompile/openwrt-armvirt
DEVICE_NAME=$openwrt/DEVICE_NAME
ipk=$hasilCompile/ipk
out=$hasilCompile/out
cr4rWRT="$rootDir/router-config/cr4rWRT"
FEEDS_CONF=$cr4rWRT/feeds.conf.default
CONFIG_FILE=$cr4rWRT/.config
DIY_P1_SH=$cr4rWRT/diy-part1.sh
DIY_P2_SH=$cr4rWRT/diy-part2.sh
TZ=Asia/Jakarta
pkgOpenwrt=$(curl -fsSL git.io/ubuntu-2004-openwrt)

[ -d $hasilCompile ] || mkdir -p $hasilCompile

msg() {
    BRAN='\033[1;37m' && VERMELHO='\e[31m' && VERDE='\e[32m' && AMARELO='\e[33m'
    AZUL='\e[34m' && MAGENTA='\e[35m' && MAG='\033[1;36m' && NEGRITO='\e[1m' && SEMCOR='\e[0m'
    case $1 in
    -ne) cor="${VERMELHO}${NEGRITO}" && echo -ne "${cor}${2}${SEMCOR}" ;;
    -ama) cor="${AMARELO}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -verm) cor="${AMARELO}${NEGRITO}[!] ${VERMELHO}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -azu) cor="${MAG}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -verd) cor="${VERDE}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -bra) cor="${BRAN}${NEGRITO}" && echo -ne "${cor}${2}${SEMCOR}" ;;
    -bar) cor="${AZUL}${NEGRITO}========================================" && echo -e "${cor}${SEMCOR}" ;;
    -bar2) cor="${AZUL}${NEGRITO}========================================" && echo -e "${cor}${SEMCOR}\n${2}\n${cor}${SEMCOR}" ;;
    esac
}

fun_bar() {
    comando="$1"
    _=$($comando >/dev/null 2>&1) &
    >/dev/null
    pid=$!
    while [[ -d /proc/$pid ]]; do
        echo -ne " \033[1;33m["
        for ((i = 0; i < 10; i++)); do
            echo -ne "\033[1;31m##"
            sleep 0.2
        done
        echo -ne "\033[1;33m]"
        sleep 1s
        echo
        tput cuu1
        tput dl1
    done
    echo -e " \033[1;33m[\033[1;31m####################\033[1;33m] - \033[1;32m100%\033[0m"
    sleep 1s
}

if [[ $pkgOpenwrt == "" ]]; then
    msg -ama "Koneksi anda terganggu"
    exit 1
fi

msg -bar2 "Persiapan sebelum Compile"
msg -ama "Update Repository"
fun_bar "sudo -E apt-get -qq update"
msg -ama "Install package openwrt"
fun_bar "sudo -E apt-get -qq install $pkgOpenwrt libncurses5-dev libncursesw5-dev gawk subversion"
msg -ama "Autoremove package"
fun_bar "sudo -E apt-get -qq autoremove --purge"
msg -ama "Clean Package"
fun_bar "sudo -E apt-get -qq clean"

COMPILE_STARTINGTIME=$(date +"%Y.%m.%d.%H%M")

# Mengambil openwrt dari immortal
msg -bar2 "Compile dimulai\n$COMPILE_STARTINGTIME\nClone source code openwrt\nStep 1"
part="Step 1"
msg -ama "$(df -hT $PWD)"
msg -ama "Clone repo $REPO_URL"
fun_bar "git clone --depth 1 $REPO_URL -b $REPO_BRANCH $openwrt"

msg -ama "Buat Folder di $hasilCompile"
fun_bar "mkdir -p $hasilCompile"
msg -ama "Buat Owner groups $hasilCompile"
fun_bar "chown $USER:$GROUPS $hasilCompile"
#ln -sf $hasilCompile/openwrt $hasilCompile/openwrt

msg -bar2 "Step 2 Part 1\nCustom Feeds"
part="Step 2 Part 1"
msg -ama "Menjalankan diy part 1"
[ -e $FEEDS_CONF ] && cp -f $FEEDS_CONF $openwrt/feeds.conf.default
chmod +x $DIY_P1_SH
cd $openwrt
fun_bar "$DIY_P1_SH"

# Install package dan segala macam menjadi rom mentah
msg -ama "Part 2\nUpdate feeds"
part="Step 2 Part 2"
cd $openwrt
fun_bar "./scripts/feeds update -a"

msg -ama "Part 3\nInstall feeds"
part="Step 2 Part 3"
cd $openwrt
fun_bar "./scripts/feeds install -a"

msg -bar2 "Step 3\nPart 1\nLoad custom configuration"
part="Step 3 Part 1"
cd $rootDir
[ -e files ] && mv files $openwrt/files
[ -e $CONFIG_FILE ] && cp -f $CONFIG_FILE $openwrt/.config
chmod +x $DIY_P2_SH
msg -ama "Menjalankan diy part 2"
cd $openwrt
fun_bar "$DIY_P2_SH"

status="sukses"
msg -bar2 "Step 4 Part 1\nMendapatkan semua package"
part="Step 4 Part 1"
cd $openwrt
make defconfig
msg -bar2 "Part 2\nMendownload semua package\nIni akan membutuhkan banyak paket internet"
part="Step 4 Part 2"
make download -j8 || status="gagal"
msg -ama "Part 3\nMencari file ukuran 1024 dan Menghapusnya"
part="Step 4 Part 3"
find dl -size -1024c -exec ls -l {} \;
find dl -size -1024c -exec rm -f {} \;

# Lanjut step jika sukses
if [[ $status != "sukses" ]]; then
    msg -ama "Maaf ada masalah di bagian $part"
    exit 1
fi

msg -bar2 "Part 5\nCompile menggunakan $(nproc) thread"
part="Step 4 Part 4"
cd $openwrt
make -j$(($(nproc) + 1)) V=s || make -j1 || make -j1 V=s || status="gagal"
grep '^CONFIG_TARGET.*DEVICE.*=y' .config | sed -r 's/.*DEVICE_(.*)=y/\1/' >$DEVICE_NAME
[ -s $DEVICE_NAME ] && $DEVICE_NAME=$(cat $DEVICE_NAME)
FILE_DATE=$(date +"%Y.%m.%d.%H%M")
status="sukses"

# Lanjut step jika sukses
if [[ $status != "sukses" ]]; then
    msg -ama "Maaf ada masalah di bagian $part"
    exit 1
fi

msg -ama "Step 5\nMengambil .ipk dari packages"
part="Step 5"
[ -d $ipk ] || mkdir -p $ipk
cp -rf $(find $openwrt/bin/packages/ -type f -name "*.ipk") $ipk && sync

msg -bar2 "Step 6\nMengambil file .tar.gz di\n$openwrt/bin/targets/*/*/*.tar.gz"
part="Step 6"
[ -d $lokarmvirt ] || mkdir -p $lokarmvirt
cp -f $openwrt/bin/targets/*/*/*.tar.gz $lokarmvirt/ && sync
sudo chmod +x make
sudo make -d -b s905x -k 5.10.96_5.4.176
status="sukses"
# Lanjut step jika sukses
if [[ $status != "sukses" ]]; then
    msg -ama "Maaf ada masalah di bagian $part"
    exit 1
fi

msg -ama "Step Akhir\nMemindahkan hasil compile tar.gz ke folder out"
part="Step Akhir"
# sudo tar -czf ipk.tar.gz ipk && mv -f ipk.tar.gz $out/ && sync
# PACKAGED_OUTPUTPATH=$out
# PACKAGED_OUTPUTDATE=$(date +"%Y.%m.%d.%H%M")
# msg -bar2 "::set-output name=status::success"
