docker-shadowsocks-libev
========================

## What is shadowsocks-libev

[Shadowsocks-libev][1] is a lightweight secured SOCKS5 proxy for embedded devices
and low-end boxes.

It is a port of [Shadowsocks][2] created by [@clowwindy][3], which is maintained by
[@madeye][4] and [@linusyang][5].

Current version: [![release](https://img.shields.io/github/release/shadowsocks/shadowsocks-libev.svg)][6]

## How to use these images

- Get [docker-compose.yml][7], then change `SS_SERVER_PORT` , `SS_PASSWORD`, `KCP_SERVER_PORT`, `KCP_CRYPT`, `KCP_MTU`, `KCP_DSCP`, `KCP_OPTIONS`,`ARUKAS_TOKEN`, `ARUKAS_SECERT`, `ARUKAS_CHECK_FEQ` provided in the file.

- Run these commands:

        # On x86 client (192.168.1.234)
        $ docker-compose up -d

        # On any LAN PC (192.168.1.XXX)
        $ curl -x socks5h://192.168.1.234:1082 https://www.youtube.com/
        $ curl -x http://192.168.1.234:7777 https://www.youtube.com/

- Set socks5 proxy in your favorite web browser.
- Set http proxy in your favorite web browser.

## License

View [license information][9] for the software contained in this image.

## User Feedback

If you find a bug, please create an [issue][10].
Feel free to send me pull requests. Thank you!

[1]: http://shadowsocks.org/
[2]: https://github.com/shadowsocks/shadowsocks
[3]: https://github.com/clowwindy
[4]: https://github.com/madeye
[5]: https://github.com/linusyang
[6]: https://github.com/shadowsocks/shadowsocks-libev/releases/latest
[7]: https://github.com/tofuliang/docker-shadowsocks-libev/raw/arukas/docker-compose.yml
[9]: https://github.com/shadowsocks/shadowsocks-libev#license