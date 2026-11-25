# Automatic OpenWRT builds for Banana Pi BPI-R4 (non PoE version)

[![LICENSE](https://img.shields.io/github/license/IncubusRK/openwrt-bpi-r4.svg?style=flat-square&label=LICENSE)](https://github.com/IncubusRK/openwrt-bpi-r4/blob/main/LICENSE)

- [Getting Started BPI-R4](https://docs.banana-pi.org/en/BPI-R4/GettingStarted_BPI-R4)
- [4PDA инструкция по прошивке](https://4pda.to/forum/index.php?showtopic=1093476&view=findpost&p=133806031)

## Прошивка с нуля без подключения консоли по RS-232

В данном устройстве eMMC и SD карта не могут работать одновременно поэтому установка прошивки производится в несколько этапов. Сначала прошивка копируется на SD карту, потом с SD карты в NAND и затем с NAND в eMMC.
В дальнейшем обновление производится через Web-интерфейс с помощью файлов [openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb](https://github.com/IncubusRK/openwrt-bpi-r4/releases/download/master-2026.11.22-0037/openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb) (FULL, prerelease master; стабильные образы — в релизах `25.12-*`)

1. Скачиваем [nand-sdcard.img.gz](https://github.com/IncubusRK/openwrt-bpi-r4/releases/latest/download/nand-sdcard.img.gz). Важно размер распакованного образа должен быть меньше 128 Мб, иначе будет невозможна установка в NAND.
2. Записываем на SD карту с помощью [Rufus](https://rufus.ie/) или [balenaEtcher](https://etcher.balena.io/)
3. Переключатели загрузки SW3 выставляем в положение 1:1 (оба переключателя в нижнем положении) для загрузки с SD
4. Вставляем SD и загружаем устройство
5. После загрузки подключаемся по SSH. Адрес по умолчанию 192.168.1.1, логин - root, пароль отсутствует
6. Вводим команды для перезагрузки и автоматического копирования прошивки с SD карты в NAND память во время старта

    ```sh
    fw_setenv bootcmd "env default bootcmd ; saveenv ; run ubi_init ; bootmenu 0"
    reboot
    ```

7. Дожидаемся завершения копирования прошивки в NAND память и загрузки устройства. Можно убедиться что устройство загрузилось повторно подключившись через SSH. При этом ключ SSH может сброситься о чем будет предупреждать SSH клиент. Для консольного клиента можно использовать команду очистки сохраненного ранее ключа ```ssh-keygen -R 192.168.1.1```
8. Выключаем устройство. Можно извлечь SD карту
9. Переключатели загрузки SW3 выставляем в положение 0:1 (левый в верхнем положении, правый в нижнем) для загрузки с NAND
10. Подключаемся по SSH и вводим команды

    ```sh
    fw_setenv bootcmd "env default bootcmd ; saveenv ; run emmc_init ; bootmenu 0"
    reboot
    ```

    После чего устройство перезагрузиться и при загрузке автоматически будет выбрано копирование прошивки в eMMC
11. Дождавшись загрузки выключаем устройство и меням положение переключателей SW3 на 1:0 (левый вниз, правый вверх) для загрузки с eMMC

## Изменение размера системного раздела

После загрузки устройства с eMMC можно изменить размер системного раздела, по умолчанию он занимает лишь часть места на eMMC.
Для этого подключаемся по SSH и вводим команду: `cfdisk /dev/mmcblk0`. Далее выбираем необходимый раздел `/dev/mmcblk0p5` стрелками на клавиатуре и выбираем команду `Resize`.
Указываем необходимый размер и после записываем изменения командой `Write`.
Встречается рекомендация не занимать всё свободное пространство, поскольку это приведет к росту размера резервной копии раздела и часто такой объем не требуется.
Также в качестве альтернативы в прошивку включена консольная утилита `parted`.

Если изменение размера раздела записать не получается, то в таком случае необходимо загрузиться с NAND (переключив SW3 в положение 0:1) и запускать `cfdisk /dev/mmcblk0` оттуда. После чего вернуть переключатели SW3 обратно на загрузку с eMMC.

Чтобы система "увидела" изменение размера раздела проще всего прошить через Web-интерфейс файл `openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb`.
Для этого нужно войти в Web-интерфейс и перейти в раздел System -> Backup / Flash Firmware

## Включение RTC

Чтобы включить поддержку аппаратных часов реального времени. Нужно установить батарейку. CR2032 с припаянным разъёмом 2 pin 1.25mm
После необходимо ввести команду:

```sh
fw_setenv bootconf_extra mt7988a-bananapi-bpi-r4-rtc
```

После перезагрузки должно стать доступно устройство `/dev/rtc0` и работать команда `hwclock`

## Импорт AmneziaWG из ссылки `vpn://`

Ссылку из приложения AmneziaVPN (`Поделиться` → `vpn://…`) можно перенести на
роутер одной командой. Утилита распакует её, перенесёт параметры обфускации
(`Jc/Jmin/Jmax/S1..S4/H1..H4/I1..I5/HeaderProtectionKey/...`) в секцию
`[Interface]` и напечатает готовый конфиг и блок `uci`:

```sh
awgimport 'vpn://AAAM2Hja…'            # конфиг + uci-команды
awgimport -i awg1 'vpn://AAAM2Hja…'    # своё имя интерфейса
awgimport --uci 'vpn://AAAM2Hja…'      # только uci-команды
awgimport --apply -i awg1 'vpn://…'    # применить и сразу поднять
```

Ссылку можно передать файлом (`awgimport link.txt`) или через stdin
(`awgimport - < link.txt`).

То же самое есть в LuCI: **Network → Interfaces → Add → Protocol: AmneziaWG VPN →
Import configuration** — вставьте ссылку в поле и нажмите «Расшифровать ссылку»,
конфигурация появится в поле ввода; дальше «Импорт настроек».

Если внутри ссылки нет контейнера `amnezia-awg` (например, только `xray`/VLESS),
утилита скажет об этом — такие ссылки настраиваются в podkop, а не здесь.

## Состав прошивки (кратко)

- **FULL** (ветки master и 25.12): podkop-engine-full (sing-box с XHTTP/REALITY)
  + xray-core, Podkop / Re:HomeProxy /
  OpenClash, zapret2, NaiveProxy, mieru, WireGuard + AmneziaWG, AdGuard Home
  (включён по умолчанию, фильтрация рекламы), полный LuCI + argon + русский язык,
  SQM/CAKE, watchcat, nlbwmon, tcpdump/iperf3/mtr, collectd-графики, дисковые
  утилиты (parted, cfdisk, e2fsprogs, fstrim, smartmontools, lsusb/lspci) и
  [luci-app-diskman](https://github.com/lisaac/luci-app-diskman) (разметка/формат/SMART из UI).
  Все прозрачные прокси **выключены по умолчанию** — включайте только один
  перехват одновременно. Геоданные Loyalsoldier, переключение через
  [luci-app-geodata](https://github.com/IncubusRK/luci-app-geodata).
- **NAND** (только 25.12): минимальный установщик SD→NAND→eMMC — AdGuard Home,
  zapret2, WG/AWG, базовый LuCI + argon + русский, parted. Без прокси-ядер и docker.
- Наши LuCI-пакеты: [luci-app-geodata](https://github.com/IncubusRK/luci-app-geodata),
  [luci-app-naiveproxy](https://github.com/IncubusRK/luci-app-naiveproxy),
  [luci-app-mieru](https://github.com/IncubusRK/openwrt-mieru) (EN/RU, релизы для 25.12 — в репо).

## Опциональные пакеты (docker, samba и др.)

Docker, samba4 и прочие опциональные пакеты **не входят в образ** — они лежат в
архиве `extra-packages.tar.gz` того же релиза, что и образ (kmod-ы привязаны к
версии ядра, архив от другого релиза не подойдёт):

```sh
tar -xzf extra-packages.tar.gz -C /tmp/extra
apk add --allow-untrusted /tmp/extra/*.apk
```

Docker: вынесите data-root на внешний диск с ext4 (NVMe SSD рекомендуется;
USB-флешка/SD быстро изнашиваются), например для NVMe:

```sh
uci set dockerd.globals.data_root='/mnt/nvme0n1p1/docker'
uci commit dockerd
service dockerd enable && service dockerd start
```
