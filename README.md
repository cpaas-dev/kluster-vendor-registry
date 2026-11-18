# kluster-vendor-registry

把上游 distribution registry 的二进制重新打包成一个多架构 OCI 镜像，用于离线 / 内网环境分发。

[![Release](https://github.com/cpaas-dev/kluster-vendor-registry/actions/workflows/release.yml/badge.svg)](https://github.com/cpaas-dev/kluster-vendor-registry/actions/workflows/release.yml)
[![Scan upstream](https://github.com/cpaas-dev/kluster-vendor-registry/actions/workflows/scan-upstream.yml/badge.svg)](https://github.com/cpaas-dev/kluster-vendor-registry/actions/workflows/scan-upstream.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-informational)

```bash
docker pull ghcr.io/cpaas-dev/kluster-vendor-registry:v3.1.2
```

## 这是什么

离线集群需要一个能直接读写 docker distribution 存储格式的镜像仓库服务。上游 Release
发的是 tar 包，里面是 `registry` 单个二进制。

本仓库把上游 GitHub Release 的发布件按目标架构解包进镜像，构建时用上游校验和校验，
只装二进制和 LICENSE，不带配置。

## 镜像内容

```plain
/cpaas/vendor/registry/
├── registry                                     # 目标架构
├── registry.sha256sum
├── LICENSE                                  # 上游许可
├── LICENSE.sha256sum
└── registry_<ver>_linux_<arch>.tar.gz.sha256    # 上游校验和，留作凭证
```

下游校验：

```bash
cd /cpaas/vendor/registry

sha256sum -c *.sha256sum
```

说明：

- 镜像 tag 和 Release 与上游 tag 1:1：`v3.1.2` → `v3.1.2`
- 构建时逐个架构比对上游校验和，不过直接失败；还会检查落盘文件确实是对应架构的
  ELF（magic + `e_machine`）
- 上游 tarball 的校验和存成 `.sha256` 而不是 `.sha256sum`，避免 `*.sha256sum`
  把它也匹配进去——那个 tarball 并不在镜像里，一并校验必然失败
- 只含目标架构。`linux/arm64` 的镜像里只有 arm64 的 registry

## 文档

- [自定义构建](docs/BUILD_YOUR_OWN.md) —— build-args、下载加速
- [发布流程](docs/RELEASE.md) —— tag 规则、定时扫描、本地调试脚本
- [贡献指南](docs/CONTRIBUTING.md)

## 相关仓库

- distribution registry <https://github.com/distribution/distribution>

## 许可

本仓库的构建脚本以 Apache-2.0 发布。打包进镜像的上游产物遵循其原始许可：
distribution registry（Apache-2.0）。
