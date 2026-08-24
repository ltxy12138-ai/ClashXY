# Third-party notices

ClashXY source code is licensed separately under `GPL-3.0-only`; see the root
`LICENSE` file.

## Mihomo core

Release builds contain an unmodified `mihomo-windows-amd64` executable from
Mihomo v1.19.30.

- Upstream project: <https://github.com/MetaCubeX/mihomo>
- Release and corresponding source: <https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.30>
- License: GNU General Public License version 3
- Embedded executable SHA-256:
  `cf894375dbc00ab6708c1314ac35bbd29059f4c37f315353aaca7f1a9c566de6`
- Full license copy: `assets/licenses/mihomo-GPL-3.0.txt`

The Mihomo executable is launched as a separate process and controlled through
its documented loopback REST API. No changes are made to its source in this
repository. Recipients can obtain the exact release source from the release link
above at no charge.

The upstream v1.19.30 README additionally asks projects unaffiliated with
MetaCubeX not to contain the word `mihomo` in their names. The ClashXY product
name follows that request.

## Flutter and Dart packages

The Windows application includes Flutter engine components and Dart/Flutter
packages listed in `pubspec.lock`. Flutter generates a `NOTICES.Z` file inside
the application bundle containing their collected license notices.

## 2S-UI

2S-UI is not bundled. The app communicates with a panel supplied and operated by
the user through its HTTPS API.
