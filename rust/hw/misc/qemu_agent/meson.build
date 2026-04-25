_libqemu_agent_rs = static_library(
  'qemu_agent',
  files('src/lib.rs'),
  override_options: ['rust_std=2021', 'build.rust_std=2021'],
  rust_abi: 'rust',
  link_with: [
    _util_rs,
    _migration_rs,
    _bql_rs,
    _qom_rs,
    _system_rs,
    _hwcore_rs,
  ],
  dependencies: [common_rs],
)

rust_devices_ss.add(when: 'CONFIG_X_QEMU_AGENT_RUST', if_true: [declare_dependency(
  link_whole: [_libqemu_agent_rs],
  variables: {'crate': 'qemu_agent'},
)])
