# Changelog

## [Unreleased](https://github.com/ruby/net-imap/tree/HEAD)

* ???

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.5.6...HEAD

## [v0.5.6](https://github.com/ruby/net-imap/tree/v0.5.6) (2025-02-07)

### What's Changed
#### 🔒 Security Fix
Fixes CVE-2025-25186 (GHSA-7fc5-f82f-cx69): A malicious server can exhaust client memory by sending `APPENDUID` or `COPYUID` responses with very large `uid-set` ranges. `Net::IMAP::UIDPlusData` expands these ranges into arrays of integers.

##### Fix with minor API changes

Set `config.parser_use_deprecated_uidplus_data` to `false` to replace `UIDPlusData` with `AppendUIDData` and `CopyUIDData`.  These classes store their UIDs as `Net::IMAP::SequenceSet` objects (_not_ expanded into arrays of integers).  Code that does not handle `APPENDUID` or `COPYUID` responses should not see any difference.  Code that does handle these responses _may_ need to be updated.

For v0.3.8, this option is not available
For v0.4.19, the default value is `true`.
For v0.5.6, the default value is `:up_to_max_size`.
For v0.6.0, the only allowed value will be `false`  _(`UIDPlusData` will be removed from v0.6)_.

##### Mitigate with backward compatible API
Adjust `config.parser_max_deprecated_uidplus_data_size` to limit the maximum `UIDPlusData` UID set size.
When `config.parser_use_deprecated_uidplus_data == true`, larger sets will crash.
When  `config.parser_use_deprecated_uidplus_data == :up_to_max_size`, larger sets will use `AppendUIDData` or `CopyUIDData`.

For v0.3,8, this limit is _hard-coded_ to 10,000.
For v0.4.19, this limit defaults to 1000.
For v0.5.6, this limit defaults to 100.
For v0.6.0, the only allowed value will be `0`  _(`UIDPlusData` will be removed from v0.6)_.

##### Please Note: unhandled responses
If the client does not add response handlers to prune unhandled responses, a malicious server can still eventually exhaust all client memory, by repeatedly sending malicious responses.  However, `net-imap` has always retained unhandled responses, and it has always been necessary for long-lived connections to prune these responses.  This is not significantly different from connecting to a trusted server with a long-lived connection.  To limit the maximum number of retained responses, a simple handler might look something like the following:

  ```ruby
  limit = 1000
  imap.add_response_handler do |resp|
    next unless resp.respond_to?(:name) && resp.respond_to?(:data)
    name = resp.name
    code = resp.data.code&.name if resp.data.is_a?(Net::IMAP::ResponseText)
    imap.responses(name) { _1.slice!(0...-limit) }
    imap.responses(code) { _1.slice!(0...-limit) }
  end
  ```

#### Added
* 🔧 Ensure ResponseParser config is mutable and non-global by @nevans in https://github.com/ruby/net-imap/pull/381
* ✨ Add SequenceSet methods for querying about duplicates by @nevans in https://github.com/ruby/net-imap/pull/384
* ✨ Add `SequenceSet#each_ordered_number` by @nevans in https://github.com/ruby/net-imap/pull/386
* ✨ Add `SequenceSet#find_ordered_index` by @nevans in https://github.com/ruby/net-imap/pull/396
* ✨ Add `SequenceSet#ordered_at` by @nevans in https://github.com/ruby/net-imap/pull/397
* ✨ Add AppendUIDData and CopyUIDData classes by @nevans in https://github.com/ruby/net-imap/pull/400
* 🔧 Add parser config for `APPENDUID`/`COPYUID`, 🗑️ Deprecate UIDPlusData by @nevans in https://github.com/ruby/net-imap/pull/401
#### Fixed
* 🐛 Fix `SequenceSet#append` when its `@string` is nil by @nevans in https://github.com/ruby/net-imap/pull/376
* 🐛 Fix SequenceSet merging in another SequenceSet by @nevans in https://github.com/ruby/net-imap/pull/377
* 🐛 Fix SequenceSet count dups with multiple "*" by @nevans in https://github.com/ruby/net-imap/pull/387
* 🥅 Re-raise `#starttls` error from receiver thread by @nevans in https://github.com/ruby/net-imap/pull/395
#### Documentation
* 📚 Fix `SequenceSet#cover?` documentation by @nevans in https://github.com/ruby/net-imap/pull/379
* 📚 Document COPYUID in tagged vs untagged responses by @nevans in https://github.com/ruby/net-imap/pull/398
#### Other Changes
* 🚚 Move UIDPlusData to its own file by @nevans in https://github.com/ruby/net-imap/pull/391
* ♻️ Parse `uid-set` as `sequence-set` without `*` by @nevans in https://github.com/ruby/net-imap/pull/393
#### Miscellaneous
* ⬆️ Bump step-security/harden-runner from 2.10.2 to 2.10.3 by @dependabot in https://github.com/ruby/net-imap/pull/375
* ⬆️ Bump step-security/harden-runner from 2.10.3 to 2.10.4 by @dependabot in https://github.com/ruby/net-imap/pull/380
* ✅ Improve test coverage for SequenceSet enums by @nevans in https://github.com/ruby/net-imap/pull/383
* ♻️✅ Refactor SequenceSet enumerator tests by @nevans in https://github.com/ruby/net-imap/pull/385
* ➕ Add "irb" to Gemfile to silence warning by @nevans in https://github.com/ruby/net-imap/pull/388
* Omit flaky test with macOS platform by @hsbt in https://github.com/ruby/net-imap/pull/389
* ✅ Improve UIDPlusData test coverage by @nevans in https://github.com/ruby/net-imap/pull/392
* 🚚 Rename UIDPLUS test file for consistency by @nevans in https://github.com/ruby/net-imap/pull/399


**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.5.5...v0.5.6


## [v0.5.5](https://github.com/ruby/net-imap/tree/v0.5.5) (2025-01-04)

<!-- Release notes generated using configuration in .github/release.yml at v0.5.5 -->

### What's Changed
#### Breaking Changes
* 🐛💥 Remove accidental `Data#attributes` method by @nevans in https://github.com/ruby/net-imap/pull/371
  _For ruby 3.2 and above, this PR is **not** a breaking change, and it fixes a YAML serialization bug._
  `Net::IMAP::Data#attributes` was only available in ruby 3.1, with `net-imap` `v0.5.2` - `v0.5.4`.  It can be replaced by `#to_h`.
#### Added
* RFC9586 UIDONLY support by @avdi in https://github.com/ruby/net-imap/pull/366
#### Documentation
* 📚 Fix rdoc issues by @nevans in https://github.com/ruby/net-imap/pull/372
* 📚 Use standard www.rfc-editor.org links for RFCs by @nevans in https://github.com/ruby/net-imap/pull/374
* 📚 Documentation updates by @nevans in https://github.com/ruby/net-imap/pull/373

### New Contributors
* @avdi made their first contribution in https://github.com/ruby/net-imap/pull/366

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.5.4...v0.5.5


## [v0.5.4](https://github.com/ruby/net-imap/tree/v0.5.4) (2024-12-22)

<!-- Release notes generated using configuration in .github/release.yml at v0.5.4 -->

### What's Changed
#### Added
* ✨ Add support for `PARTIAL` extension (RFC9394) by @nevans in https://github.com/ruby/net-imap/pull/367
#### Fixed
* 🐛 Fix partial-range encoding of exclusive ranges by @nevans in https://github.com/ruby/net-imap/pull/370
#### Documentation
* 📚 Fix documentation for `#fetch` by @nevans in https://github.com/ruby/net-imap/pull/369


**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.5.3...v0.5.4


## [v0.5.3](https://github.com/ruby/net-imap/tree/v0.5.3) (2024-12-20)

### What's Changed
#### Added
* ✨ Add support for VANISHED responses by @nevans in https://github.com/ruby/net-imap/pull/329
#### Documentation
* 📚 Fix rdoc issues by @nevans in https://github.com/ruby/net-imap/pull/365

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.5.2...v0.5.3


## [v0.5.2](https://github.com/ruby/net-imap/tree/v0.5.2) (2024-12-16)

<!-- Release notes generated using configuration in .github/release.yml at v0.5.2 -->

### What's Changed
#### Added
* 🥅 Raise ArgumentError on multiple search charset args by @nevans in https://github.com/ruby/net-imap/pull/363
* ✨ Add keyword argument for search `charset` by @nevans in https://github.com/ruby/net-imap/pull/364
* ✨ Add basic `ESEARCH` support (RFC4466, RFC4731) by @nevans in https://github.com/ruby/net-imap/pull/333
#### Fixed
* 🐛 Return empty SearchResult for no search result by @nevans in https://github.com/ruby/net-imap/pull/362
#### Documentation
* 📚 Fix README example by @nevans in https://github.com/ruby/net-imap/pull/354
* 📦📚  Add release.yml for better release note generation by @nevans in https://github.com/ruby/net-imap/pull/355
* 📚💄 Fix rdoc 6.8 CSS styles by @nevans in https://github.com/ruby/net-imap/pull/356
* 📚 Update IMAP#search docs (again) by @nevans in https://github.com/ruby/net-imap/pull/360
* 📚 Consistent heading levels inside method rdoc by @nevans in https://github.com/ruby/net-imap/pull/361
#### Other Changes
* ✨ Add Data polyfill for ruby 3.1 by @nevans in https://github.com/ruby/net-imap/pull/352
* ♻️ Refactor internal command data classes by @nevans in https://github.com/ruby/net-imap/pull/358
#### Miscellaneous
* 🔥 Drop YAML.unsafe_load_file refinement (tests only) by @nevans in https://github.com/ruby/net-imap/pull/353
* ⬆️ Bump step-security/harden-runner from 2.10.1 to 2.10.2 by @dependabot in https://github.com/ruby/net-imap/pull/357
* Enabled windows-latest on GHA by @hsbt in https://github.com/ruby/net-imap/pull/359


**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.5.1...v0.5.2


## [v0.5.1](https://github.com/ruby/net-imap/tree/v0.5.1) (2024-11-08)

### What's Changed

#### Added
* ✨ Add `SequenceSet#deconstruct` by @nevans in https://github.com/ruby/net-imap/pull/343
* ✨ Coerce `Set`, `:*`, `#to_sequence_set` search args into sequence-set by @nevans in https://github.com/ruby/net-imap/pull/351
* ✨ Enable parenthesized lists in search criteria by @nevans in https://github.com/ruby/net-imap/pull/345

#### Fixed
* 🐛 Ensure `set` is loaded in ruby 3.1 by @nevans in https://github.com/ruby/net-imap/pull/342
* 🐛 Fix `SequenceSet.try_convert` by @nevans in https://github.com/ruby/net-imap/pull/349

#### Documentation
* 📚 Update `#search` documentation by @nevans in https://github.com/ruby/net-imap/pull/347

#### Other Changes
* ♻️  Reduce duplication in normalizing search args by @nevans in https://github.com/ruby/net-imap/pull/348

#### Miscellaneous
* Make simplecov-json as optional dependency by @hsbt in https://github.com/ruby/net-imap/pull/344
* Removed needless workaround by @hsbt in https://github.com/ruby/net-imap/pull/346

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.5.0...v0.5.1


## [v0.5.0](https://github.com/ruby/net-imap/tree/v0.5.0) (2024-10-16)

### What's Changed

#### Breaking Changes
* 💥 Drop ruby 2.7 and 3.0 support, and require ruby 3.1 by @nevans in https://github.com/ruby/net-imap/pull/276
* 💥⚡ Simplify `header-fld-name` parser (backward incompatible) by @nevans in https://github.com/ruby/net-imap/pull/216
   For example, `HEADER.FIELDS (Content-Type)` and `HEADER.FIELDS ("Content-Type")` are semantically identical, and a server may choose to return the quoted version.
   * Before this change, the FetchData attr header name would be quoted if the server sent the field name quoted.
   * After this change, the header field names will always be unquoted by the parser, so the result will always available via `fetch_data.header_fields("Content-Type")` or `fetch_data.attr_upcase["HEADER.FIELDS (CONTENT-TYPE)"]`.
* 💥 Replace MessageSet with SequenceSet by @nevans in https://github.com/ruby/net-imap/pull/282
   Most of the changes are bugfixes or allow something new to work that didn't work before.  See [the PR](https://github.com/ruby/net-imap/pull/282) for more details.
   This affects `#search`, `#uid_search`, `#sort`, `#uid_sort`, `#fetch`, `#uid_fetch`, `#store`, `#uid_store`, `#copy`, `#uid_copy`, `#move`, `#uid_move`, and `#uid_expunge`.
* 💥 SequenceSet input validation for Set, Array, and enumerables by @nevans in https://github.com/ruby/net-imap/pull/319
   * Array inputs can still be deeply nested.  _This is unchanged._
   * Set inputs can only contain integers and `"*"` or `:*`, to be consistent with `SequenceSet#to_set`.
   * Other `Enumerables` will only be converted if they implement `#to_sequence_set`.
* 🔥 Remove deprecated `#client_thread` attr_reader by @nevans in https://github.com/ruby/net-imap/pull/321
   _`#client_thread` was deprecated by `v0.4.0`._
* 🔥 Drop deprecated BodyType structs by @nevans in https://github.com/ruby/net-imap/pull/323
   _These structs were deprecated by `v0.4.0`._

#### Added
* ✨ Add `#extract_responses` method by @nevans in https://github.com/ruby/net-imap/pull/330 _Also backported to `v0.4.17`._
* ✨ New config option to return frozen dup from `#responses` by @nevans in https://github.com/ruby/net-imap/pull/334 _Also backported to `v0.4.17`._
* 🥅 Improve SequenceSet frozen errors by @nevans in https://github.com/ruby/net-imap/pull/331 _Also backported to `v0.4.17`._
* 📚 SequenceSet API is considered stable now by @nevans in https://github.com/ruby/net-imap/pull/318
* 🔒 Enforce `LOGINDISABLED` requirement by @nevans in https://github.com/ruby/net-imap/pull/307
  To workaround buggy servers, `config.enforce_logindisabled` can be set to `:when_capabilities_cached` or `false`.
* 🔒 SASL DIGEST-MD5: realm, host, service_name, etc by @nevans in https://github.com/ruby/net-imap/pull/284
   _Please note that the `DIGEST-MD5` SASL mechanism is insecure and deprecated._

#### Deprecations
* 🔊 Warn about deprecated `#responses` usage by @nevans in https://github.com/ruby/net-imap/pull/97
   To silence these warnings:
   * pass a block to `#responses` _(supported since `v0.4.0`)_,
   * pass a response type to `#responses` for a frozen copied array _(since `v0.4.17`)_,
   * set `config.responses_without_block` to `:silence_deprecation_warning` _(since `v0.4.13`)_,
   * set `config.responses_without_block` to `:frozen_dup` for a frozen copy _(since `v0.4.17`)_,
   * use `#clear_responses` instead _(since `v0.4.0`)_,
   * use `#extract_responses` instead _(since `v0.4.17`)_.
* 🗑️ Deprecate `MessageSet` by @nevans in https://github.com/ruby/net-imap/pull/282
   `MessageSet` was only intended for internal use, and all internal usage has been replaced.

#### Fixed
* 🐛 Fix #send_data to send DateTime as time by @taku0 in https://github.com/ruby/net-imap/pull/313
   _Also backported to `v0.4.15`._
* 🐛 Fix #header_fld_name to handle quoted strings correctly by @taku0 in https://github.com/ruby/net-imap/pull/315
   _Also backported to `v0.4.16`._
* 🐛 Fix SequenceSet[input] when input is a SequenceSet by @nevans in https://github.com/ruby/net-imap/pull/326
   _Also backported to `v0.4.17`._
* 🐛 Fix Set inputs for SequenceSet by @nevans in https://github.com/ruby/net-imap/pull/332
   _This bug was introduced by https://github.com/ruby/net-imap/pull/319, which had not been previously released._

#### Other Changes
* 🔧 Update default config for v0.5 by @nevans in https://github.com/ruby/net-imap/pull/305
* ♻️ Use Integer.try_convert (new in ruby 3.1+) by @nevans in https://github.com/ruby/net-imap/pull/316
* 🗑️ Add `category: :deprecated` to calls to `warn` by @nevans in https://github.com/ruby/net-imap/pull/322
* ♻️ Extract SASL::Authenticators#normalize_name by @nevans in https://github.com/ruby/net-imap/pull/309
* 🔒 📚  Improvements and docs for SASL::ClientAdapter by @nevans in https://github.com/ruby/net-imap/pull/320
* ♻️ Use SASL::ClientAdapter by @nevans in https://github.com/ruby/net-imap/pull/194

#### Documentation
* 📚 Update Config rdoc for v0.5 by @nevans in https://github.com/ruby/net-imap/pull/306
* 📚 Update SASL documentation by @nevans in https://github.com/ruby/net-imap/pull/308
* 📚 SequenceSet API is considered stable now by @nevans in https://github.com/ruby/net-imap/pull/318
* 🔒 📚  Improvements and docs for SASL::ClientAdapter by @nevans in https://github.com/ruby/net-imap/pull/320

#### Miscellaneous
* ✅ Add a Mutex to FakeServer (for tests only) by @nevans in https://github.com/ruby/net-imap/pull/317
   _Also backported to `v0.4.17`._
* ⬆️ Bump step-security/harden-runner from 2.8.1 to 2.9.0 by @dependabot in https://github.com/ruby/net-imap/pull/311
* ⬆️ Bump step-security/harden-runner from 2.9.0 to 2.9.1 by @dependabot in https://github.com/ruby/net-imap/pull/312
* Bump step-security/harden-runner from 2.9.1 to 2.10.1 by @dependabot in https://github.com/ruby/net-imap/pull/325
* 🔨📚 Fix rdoc => ghpages workflow by @nevans in https://github.com/ruby/net-imap/pull/335
* ✅ Fix GH action for rubygems Trusted Publishing by @nevans in https://github.com/ruby/net-imap/pull/340
   _Also backported to `v0.4.17`._
* ✅ Setup simplecov by @nevans in https://github.com/ruby/net-imap/pull/328

### New Contributors
* @taku0 made their first contribution in https://github.com/ruby/net-imap/pull/313

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.14...v0.5.0
_(Note that `v0.4.x` releases since `v0.4.14` have used the [`v0.4-stable`](https://github.com/ruby/net-imap/tree/v0.4-stable) branch.)_


## [v0.4.19](https://github.com/ruby/net-imap/tree/v0.4.19) (2025-02-07)

### What's Changed

#### 🔒 Security Fix
Fixes CVE-2025-25186 (GHSA-7fc5-f82f-cx69): A malicious server can exhaust client memory by sending `APPENDUID` or `COPYUID` responses with very large `uid-set` ranges. `Net::IMAP::UIDPlusData` expands these ranges into arrays of integers.

##### Fix with minor API changes

Set `config.parser_use_deprecated_uidplus_data` to `false` to replace `UIDPlusData` with `AppendUIDData` and `CopyUIDData`.  These classes store their UIDs as `Net::IMAP::SequenceSet` objects (_not_ expanded into arrays of integers).  Code that does not handle `APPENDUID` or `COPYUID` responses should not see any difference.  Code that does handle these responses _may_ need to be updated.

For v0.3.8, this option is not available
For v0.4.19, the default value is `true`.
For v0.5.6, the default value is `:up_to_max_size`.
For v0.6.0, the only allowed value will be `false`  _(`UIDPlusData` will be removed from v0.6)_.

##### Mitigate with backward compatible API
Adjust `config.parser_max_deprecated_uidplus_data_size` to limit the maximum `UIDPlusData` UID set size.
When `config.parser_use_deprecated_uidplus_data == true`, larger sets will crash.
When  `config.parser_use_deprecated_uidplus_data == :up_to_max_size`, larger sets will use `AppendUIDData` or `CopyUIDData`.

For v0.3,8, this limit is _hard-coded_ to 10,000.
For v0.4.19, this limit defaults to 1000.
For v0.5.6, this limit defaults to 100.
For v0.6.0, the only allowed value will be `0`  _(`UIDPlusData` will be removed from v0.6)_.

##### Please Note: unhandled responses
If the client does not add response handlers to prune unhandled responses, a malicious server can still eventually exhaust all client memory, by repeatedly sending malicious responses.  However, `net-imap` has always retained unhandled responses, and it has always been necessary for long-lived connections to prune these responses.  This is not significantly different from connecting to a trusted server with a long-lived connection.  To limit the maximum number of retained responses, a simple handler might look something like the following:

  ```ruby
  limit = 1000
  imap.add_response_handler do |resp|
    next unless resp.respond_to?(:name) && resp.respond_to?(:data)
    name = resp.name
    code = resp.data.code&.name if resp.data.in?(Net::IMAP::ResponseText)
    imap.responses(name) { _1.slice!(0...-limit) }
    imap.responses(code) { _1.slice!(0...-limit) }
  end
  ```

#### Added
* 🔧 ResponseParser config is mutable and non-global (backports #381) by @nevans in https://github.com/ruby/net-imap/pull/382
* ✨ SequenceSet ordered entries methods (backports to v0.4-stable) by @nevans in https://github.com/ruby/net-imap/pull/402
  Backports the following:
  * ✨ Add SequenceSet methods for querying about duplicates by @nevans in https://github.com/ruby/net-imap/pull/384
  * ✨ Add `SequenceSet#each_ordered_number` by @nevans in https://github.com/ruby/net-imap/pull/386
  * ✨ Add `SequenceSet#find_ordered_index` by @nevans in https://github.com/ruby/net-imap/pull/396
  * ✨ Add `SequenceSet#ordered_at` by @nevans in https://github.com/ruby/net-imap/pull/397
* ✨ Backport UIDPlusData, AppendUIDData, CopyUIDData to v0.4 by @nevans in https://github.com/ruby/net-imap/pull/404
  Backports the following:
  * ✨ Add AppendUIDData and CopyUIDData classes by @nevans in https://github.com/ruby/net-imap/pull/400
  * 🔧 Add parser config for `APPENDUID`/`COPYUID`, 🗑️ Deprecate UIDPlusData by @nevans in https://github.com/ruby/net-imap/pull/401

#### Fixed
* 🐛 Backport SequenceSet bugfixes (#376, #377) to v0.4 by @nevans in https://github.com/ruby/net-imap/pull/378
  Backports the following:
  * 🐛 Fix `SequenceSet#append` when its `@string` is nil by @nevans in https://github.com/ruby/net-imap/pull/376
  * 🐛 Fix SequenceSet merging in another SequenceSet by @nevans in https://github.com/ruby/net-imap/pull/377
* 🥅 Re-raise `#starttls` error from receiver thread (backport #395 to v0.4) by @nevans in https://github.com/ruby/net-imap/pull/403

#### Other Changes


**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.18...v0.4.19


## [v0.4.18](https://github.com/ruby/net-imap/tree/v0.4.18) (2024-11-08)

### What's Changed
* 🐛 Fix `SequenceSet.try_convert` by @nevans in https://github.com/ruby/net-imap/pull/350 (backports https://github.com/ruby/net-imap/pull/349)

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.17...v0.4.18


## [v0.4.17](https://github.com/ruby/net-imap/tree/v0.4.17) (2024-10-13)

### What's Changed
#### Added features
* ✨ Add `#extract_responses` method by @nevans in https://github.com/ruby/net-imap/pull/337  (backports https://github.com/ruby/net-imap/pull/330)
* ✨ New config option to return frozen dup from `#responses` by @nevans in https://github.com/ruby/net-imap/pull/339 (backports https://github.com/ruby/net-imap/pull/334) 
  _This will become the default in `v0.6.0`._

#### Bug fixes
* 🐛 Fix SequenceSet[input] when input is a SequenceSet by @nevans in https://github.com/ruby/net-imap/pull/327 (backports https://github.com/ruby/net-imap/pull/326)

#### Other Changes
* 🥅 Improve SequenceSet frozen errors by @nevans in https://github.com/ruby/net-imap/pull/338  (backports https://github.com/ruby/net-imap/pull/331)

#### Miscellaneous
* ✅ Add a Mutex to FakeServer (for tests only) by @nevans in https://github.com/ruby/net-imap/pull/336 (backports https://github.com/ruby/net-imap/pull/317)
* ✅ Fix GH action for Rubygems Trusted Publishing by @nevans in https://github.com/ruby/net-imap/pull/341 (backports https://github.com/ruby/net-imap/pull/340)

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.16...v0.4.17


## [v0.4.16](https://github.com/ruby/net-imap/tree/v0.4.16) (2024-09-04)

### What's Changed

#### Fixed
* 🐛 Fix #header_fld_name to handle quoted strings correctly by @taku0 in https://github.com/ruby/net-imap/pull/315

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.15...v0.4.16


## [v0.4.15](https://github.com/ruby/net-imap/tree/v0.4.15) (2024-08-28)

### What's Changed

#### Fixed
* 🐛 Fix #send_data to send DateTime as time by @taku0 in https://github.com/ruby/net-imap/pull/313

### New Contributors
* @taku0 made their first contribution in https://github.com/ruby/net-imap/pull/313

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.14...v0.4.15


## [v0.4.14](https://github.com/ruby/net-imap/tree/v0.4.14) (2024-06-22)

### What's Changed

#### Added
* ✨ Add Config methods: `#to_h`, `#update`, and `#with` by @nevans in https://github.com/ruby/net-imap/pull/300
* 🔧 Add versioned defaults by @nevans in https://github.com/ruby/net-imap/pull/302
* 🔧 Add `Config#load_defaults` by @nevans in https://github.com/ruby/net-imap/pull/301

#### Fixed
* 🐛 Fix Config#clone to clone internal data struct by @nevans in https://github.com/ruby/net-imap/pull/303
* 🔇 Fix ruby 2.7 warnings by @nevans in https://github.com/ruby/net-imap/pull/304

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.13...v0.4.14


## [v0.4.13](https://github.com/ruby/net-imap/tree/v0.4.13) (2024-06-16)

### What's Changed

#### ✨ Added features
* 🔧 Add Config class for `debug`, `open_timeout`, and `idle_response_timeout` by @nevans in https://github.com/ruby/net-imap/pull/291
  * `Net::IMAP.config` for global configuration.  This enables global defaults for previously client-local configuration:
    * `open_timeout`
    * `idle_response_timeout`
  * config keyword parameters for `Net::IMAP.new`
  * `Net::IMAP#config` for client configuration.  This enables client-local overrides of previously global configuration:
    * `debug`
  * ♻️ Minor Config class tidy up by @nevans in https://github.com/ruby/net-imap/pull/295
* 🔧 Add config option for `sasl_ir` by @nevans in https://github.com/ruby/net-imap/pull/294
* 🔊 Add config option for `responses_without_block` by @nevans in https://github.com/ruby/net-imap/pull/293

#### 📖 Documentation
* 📖 Improve #idle and #idle_done rdoc by @nevans in https://github.com/ruby/net-imap/pull/290
* 📚 Update rdoc for Config and related updates by @nevans in https://github.com/ruby/net-imap/pull/297
* 📚 Improve rdoc for Net::IMAP.new ssl: params by @nevans in https://github.com/ruby/net-imap/pull/298
* 📚 Improve Config class rdoc by @nevans in https://github.com/ruby/net-imap/pull/296

#### 🛠️ Other changes
* 📦 Don't keep .github, .gitignore, .mailmap in gem by @nevans in https://github.com/ruby/net-imap/pull/299
* ⬆️ Bump step-security/harden-runner from 2.8.0 to 2.8.1 by @dependabot in https://github.com/ruby/net-imap/pull/292

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.12...v0.4.13


## [v0.4.12](https://github.com/ruby/net-imap/tree/v0.4.12) (2024-06-01)

### What's Changed
* 📚 Fix many rdoc spelling mistakes by @nevans in https://github.com/ruby/net-imap/pull/279
* 📦 Update workflow with configure_trusted_publisher by @nevans in https://github.com/ruby/net-imap/pull/280
* 🔍 Simplify handling of ResponseParser test failures by @nevans in https://github.com/ruby/net-imap/pull/281
* ⬆️ Bump step-security/harden-runner from 2.7.1 to 2.8.0 by @dependabot in https://github.com/ruby/net-imap/pull/289
* Clarify the license of net-imap by @shugo in https://github.com/ruby/net-imap/pull/275


**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.11...v0.4.12


## [v0.4.11](https://github.com/ruby/net-imap/tree/v0.4.11) (2024-05-08)

### What's Changed

#### Server workarounds
* Consider extra empty space in BODYSTRUCTURE by @gaynetdinov in https://github.com/ruby/net-imap/pull/271
 
#### Miscellaneous
* 🐛 Fix parser benchmarks generation by @nevans in https://github.com/ruby/net-imap/pull/266
* ✅ Add basic test for SEARCH / UID SEARCH command by @nevans in https://github.com/ruby/net-imap/pull/267
* 📧 Update gem email address and git mailmap by @nevans in https://github.com/ruby/net-imap/pull/264
* ✅ Update Github test workflow name by @nevans in https://github.com/ruby/net-imap/pull/268
* ⬆️ Bump actions/configure-pages from 4 to 5 by @dependabot in https://github.com/ruby/net-imap/pull/270
* 🔧🔒 Configure RubyGems Trusted Publishing by @nevans in https://github.com/ruby/net-imap/pull/265

### New Contributors
* @gaynetdinov made their first contribution in https://github.com/ruby/net-imap/pull/271

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.10...v0.4.11


## [v0.4.10](https://github.com/ruby/net-imap/tree/v0.4.10) (2024-02-04)

### What's Changed

#### Fixes
* 🐛 Do not automatically freeze SearchResult by @nevans in https://github.com/ruby/net-imap/pull/263
  _This fixes a backwards incompatible change in `v0.4.8` that affected the `mail` gem.
  See https://github.com/ruby/net-imap/issues/262, reported by @stanley90._

#### Documentation
* 📚 Workaround rdoc method visibility issue by @nevans in https://github.com/ruby/net-imap/pull/257
* 📚 Workaround rdoc issue with `:yield:` and visibility by @nevans in https://github.com/ruby/net-imap/pull/258

#### Miscellaneous
* ⬆️ Bump actions/upload-pages-artifact from 2 to 3 by @dependabot in https://github.com/ruby/net-imap/pull/256
* ⬆️ Bump actions/deploy-pages from 3 to 4 by @dependabot in https://github.com/ruby/net-imap/pull/255
* Renew test certificates by @sorah in https://github.com/ruby/net-imap/pull/259
* Add base64 dev dependency by @hsbt in https://github.com/ruby/net-imap/pull/261
* Import sample code from ruby/ruby by @hsbt in https://github.com/ruby/net-imap/pull/260

### New Contributors
* @sorah made their first contribution in https://github.com/ruby/net-imap/pull/259

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.9...v0.4.10


## [v0.4.9.1](https://github.com/ruby/net-imap/tree/v0.4.9.1) (2024-01-05)

### What's Changed
* Renew test certificates by @sorah in https://github.com/ruby/net-imap/pull/259

### New Contributors
* @sorah made their first contribution in https://github.com/ruby/net-imap/pull/259

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.9...v0.4.9.1


## [v0.4.9](https://github.com/ruby/net-imap/tree/v0.4.9) (2023-12-24)

### What's Changed

#### Known Issues
* SearchResult (returned by `#search`) is frozen, which is backward incompatible https://github.com/ruby/net-imap/issues/262
   _Broken since v0.4.8.  Fixed in v0.4.10. [#263](https://github.com/ruby/net-imap/pull/263)_

#### Added
* ✨ Add `SequenceSet#overlap?` alias for `intersect?` by @nevans in https://github.com/ruby/net-imap/pull/252
* ✨ Preserving sequence set order by @nevans in https://github.com/ruby/net-imap/pull/254
  * Add `SequenceSet#entries` and `#each_entry`, for unsorted iteration
  * Add `SequenceSet#append`, to keep unsorted order when modifying the set

#### Documentation
* 📚 Fix "not not" in FetchData docs by @nevans in https://github.com/ruby/net-imap/pull/248
* 📚 Document SequenceSet "Normalized form" by @nevans in https://github.com/ruby/net-imap/pull/254

#### Other Changes
* Remove redundant calls in sort_internal and thread_internal by @gobijan in https://github.com/ruby/net-imap/pull/251

#### Miscellaneous
* ✅ Document and test workaround for invalid "\*" in FLAGS by @nevans in https://github.com/ruby/net-imap/pull/249
* ✅ Limit CI rubygems for 2.7 compatibility by @nevans in https://github.com/ruby/net-imap/pull/253

### New Contributors
* @gobijan made their first contribution in https://github.com/ruby/net-imap/pull/251

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.8...v0.4.9


## [v0.4.8](https://github.com/ruby/net-imap/tree/v0.4.8) (2023-12-12)

### What's Changed

#### Known Issues
* SearchResult (returned by `#search`) is frozen, which is backward incompatible https://github.com/ruby/net-imap/issues/262
   _Fixed in v0.4.10. [#263](https://github.com/ruby/net-imap/pull/263)_

#### Added
* ✨ Improve SequenceSet with Set, Range, Enumerable methods by @nevans in https://github.com/ruby/net-imap/pull/239
* ✨ Add support for the `CONDSTORE` extension (RFC7162) by @nevans in https://github.com/ruby/net-imap/pull/236
   _NOTE: `#search` and `#uid_search` have been updated to return `SearchResult` rather than `Array`. `SearchResult` inherits from `Array`, for backward compatibility._

#### Fixed
* 🩹 Workaround invalid Gmail FLAGS response by @nevans in https://github.com/ruby/net-imap/pull/246
* 🐛 Fix broken `QUOTA`/`QUOTAROOT` response parsing by @nevans in https://github.com/ruby/net-imap/pull/247

#### Documentation
* 📚 Update extension docs for IMAP4rev2, STATUS=SIZE by @nevans in https://github.com/ruby/net-imap/pull/242
* 📚 List all currently supported response codes by @nevans in https://github.com/ruby/net-imap/pull/243

#### Miscellaneous
* Bump actions/configure-pages from 3 to 4 by @dependabot in https://github.com/ruby/net-imap/pull/245
* Bump actions/deploy-pages from 2 to 3 by @dependabot in https://github.com/ruby/net-imap/pull/244

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.7...v0.4.8


## [v0.4.7](https://github.com/ruby/net-imap/tree/v0.4.7) (2023-11-29)

### What's Changed
* Provide a 'Changelog' link on rubygems.org/gems/net-imap by @mark-young-atg in https://github.com/ruby/net-imap/pull/235
* ⚡️ Simplify and speed up `SEARCH` response parsing by @nevans in https://github.com/ruby/net-imap/pull/238
* 🩹 Workaround buggy outlook.com address lists by @nevans in https://github.com/ruby/net-imap/pull/240

### New Contributors
* @mark-young-atg made their first contribution in https://github.com/ruby/net-imap/pull/235

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.6...v0.4.7


## [v0.4.6](https://github.com/ruby/net-imap/tree/v0.4.6) (2023-11-21)

### What's Changed

#### Changed
* 🩹 Workaround servers that don't send required `SP` when `resp-text` is empty by @nevans in https://github.com/ruby/net-imap/pull/230
* ⚡️ Simplify and speed up `envelope` and `address` parsing by @nevans in https://github.com/ruby/net-imap/pull/232
* ⚡️ Simplify and speed up `mailbox-list` parsing by @nevans in https://github.com/ruby/net-imap/pull/233
* ⚡ Simplify and speed up `thread-data` response parsing by @nevans in https://github.com/ruby/net-imap/pull/234

#### Documentation
* 📚 Update `#status` docs for `DELETED` (IMAP4rev2) by @nevans in https://github.com/ruby/net-imap/pull/227

#### Miscellaneous
* 📈 Fix benchmark string encoding by @nevans in https://github.com/ruby/net-imap/pull/231

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.5...v0.4.6


## [v0.4.5](https://github.com/ruby/net-imap/tree/v0.4.5) (2023-11-13)

### What's Changed

#### ✨ Added
##### IMAP extension support
* ✨ Add fetch support for `BINARY` and `BINARY.SIZE` by @nevans in https://github.com/ruby/net-imap/pull/207
* ✨ Add fetch support for Gmail's `X-GM-EXT-1` extensions by @nevans in https://github.com/ruby/net-imap/pull/209
* ✨ Add support for `OBJECTID` extension (RFC8474) by @nevans in https://github.com/ruby/net-imap/pull/226
  * `MAILBOXID` ResponseCode
  * `MAILBOXID` attribute for `Net::IMAP#status`
  * `EMAILID` and `THREADID` message attributes to `Net::IMAP#fetch`/`#uid_fetch` and `FetchData#emailid`/`#threadid`

##### Other API improvements
* ✨ Allow `decode_datetime` to work without dquotes by @nevans in https://github.com/ruby/net-imap/pull/218
* ✨ Add FetchData msg-att methods and update rdoc by @nevans in https://github.com/ruby/net-imap/pull/220

#### ♻️ Changed
* ⚡ Better Faster Cleaner `STATUS` parsing by @nevans in https://github.com/ruby/net-imap/pull/225

#### 📚 Documentation
* 📚 Add :nodoc: to internal parser utils by @nevans in https://github.com/ruby/net-imap/pull/221
* 💄 Fix styles.css customization for RDoc 6.6 by @nevans in https://github.com/ruby/net-imap/pull/222
* ✨ Add FetchData msg-att methods and update rdoc by @nevans in https://github.com/ruby/net-imap/pull/220
* 📚 Improve `STATUS` attribute documentation by @nevans in https://github.com/ruby/net-imap/pull/225

#### Miscellaneous
* 🔎 Simplify parser test debugging by @nevans in https://github.com/ruby/net-imap/pull/223
* 📈 Update parser benchmark comparison by @nevans in https://github.com/ruby/net-imap/pull/224

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.4...v0.4.5


## [v0.4.4](https://github.com/ruby/net-imap/tree/v0.4.4) (2023-11-03)

### What's Changed

#### Performance
* ⚡ Parse expected chars using `String#getbyte` by @nevans in https://github.com/ruby/net-imap/pull/215
* ⚡ Simplify `header-fld-name` parser (backward compatible) by @nevans in https://github.com/ruby/net-imap/pull/217

#### Error handling
* 🥅 Return empty array for missing server response by @nevans in https://github.com/ruby/net-imap/pull/214

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.3...v0.4.4


## [v0.4.3](https://github.com/ruby/net-imap/tree/v0.4.3) (2023-10-30)

### What's Changed

#### Fixes
* 🐛 Fix unbalanced parens in `body-fld-lang` parsing by @nevans in https://github.com/ruby/net-imap/pull/204

#### Error handling
* 🥅 Validate `response-tagged` in the parser by @nevans in https://github.com/ruby/net-imap/pull/198
* 🥅 Return `UnparsedData` for unhandled response-data by @nevans in https://github.com/ruby/net-imap/pull/200
* 🥅 Update parsing of unknown numeric response types by @nevans in https://github.com/ruby/net-imap/pull/213

#### Performance
* ⚡ Simpler, faster `response-data` parser by @nevans in https://github.com/ruby/net-imap/pull/201
* ⚡ Simpler, faster `msg-att` parser (for fetch responses) by @nevans in https://github.com/ruby/net-imap/pull/205
* ⚡ Simpler, faster `resp-text-code` parser (for response codes) by @nevans in https://github.com/ruby/net-imap/pull/211
* ⚡ Update flag parsing: FLAGS, LIST, PERMANENTFLAGS by @nevans in https://github.com/ruby/net-imap/pull/212

#### Changes
* ✨ Update `response-data` parser w/stubs for all extensions by @nevans in https://github.com/ruby/net-imap/pull/202
* ♻️ Update `response` and `continue-req` to new parser style by @nevans in https://github.com/ruby/net-imap/pull/199
* ♻️ Refactor `response-data` methods to match ABNF by @nevans in https://github.com/ruby/net-imap/pull/203

#### Documentation
* 📚 Fix `XOAuth2Authenticator` rdoc typo by @nevans in https://github.com/ruby/net-imap/pull/196
* 📚 Fixing and formatting docs by @nevans in https://github.com/ruby/net-imap/pull/197

#### Miscellaneous
* 📈 Add benchmark rake task to compare gem versions by @nevans in https://github.com/ruby/net-imap/pull/208
* Set utf-8 encoding when looking for VERSION in the file. by @debasishbsws in https://github.com/ruby/net-imap/pull/210

### New Contributors
* @debasishbsws made their first contribution in https://github.com/ruby/net-imap/pull/210

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.2...v0.4.3


## [v0.4.2](https://github.com/ruby/net-imap/tree/v0.4.2) (2023-10-20)

### What's Changed
* 🔒 SASL: Clarify usage of username vs authcid vs authzid by @nevans in https://github.com/ruby/net-imap/pull/187
  * Improved SASL authenticator parameter documentation.
  * Aliases have been added from `username` to `authcid` or `authzid`—or in the other direction, from `authcid` or `authzd` to `username`.
  * `OAuthBearerAuthenticator` may now receive two arguments, to match the common `authenticate(username, secret)` style.  `authzid` (i.e. `username`) is still optional for the mechanism (although in practice many servers do require it).
  * Instead of raising an exception, conflicting arguments are silently ignored.  This allows more specific arguments (like `authcid` or a keyword argument) to override more generic terms (like `username` or a positional argument).  This improves compatibility with other projects, and can also simplify dynamic mechanism negotiation.
  * Keyword argument support has been added to the deprecated `LOGIN` and `CRAM-MD5` mechanisms.  This is for consistency and compatibility with other projects.  These mechanisms _are obsolete and should be avoided_.
* ✨ Add `secret` alias (for `password`, `oauth2_token`, etc) to relevant SASL mechanisms by @nevans in https://github.com/ruby/net-imap/pull/195

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.1...v0.4.2


## [v0.4.1](https://github.com/ruby/net-imap/tree/v0.4.1) (2023-10-09)

### What's Changed
* 📚 Fix a few documentation mistakes by @nevans in https://github.com/ruby/net-imap/pull/193
* 🔒⚗️ Add experimental SASL::ClientAdapter by @nevans in https://github.com/ruby/net-imap/pull/183
  This code is not yet used by `Net::IMAP#authenticate` (see https://github.com/ruby/net-imap/pull/194).  It is released in experimental form in order to simplify using it from other projects, to facilitate collaborating and iterating on a broadly useful API.

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.4.0...v0.4.1


## [v0.4.0](https://github.com/ruby/net-imap/tree/v0.4.0) (2023-10-04)

### What's Changed

Most notably, support has been added for the `SASL-IR`, `ENABLE`, and `UTF-8=ACCEPT` extensions, and for many SASL mechanisms: `EXTERNAL`, `ANONYMOUS`, `OAUTHBEARER`, `SCRAM-SHA-1`, and `SCRAM-SHA-256`.

#### 💥 Breaking changes
* 💥 ⬆️ Drop v2.6 support; Require v2.7.3; Use "..." arg by @nevans in https://github.com/ruby/net-imap/pull/89
  The test suite passes under ruby 2.7, although it does print some warnings for experimental pattern matching.
* 💥 Return an empty array (rather than nil) when the server doesn't send any responses, by @nevans in https://github.com/ruby/net-imap/pull/192
  This can affect `list`, `xlist`, `getquota`, `lsub`, `expunge`, `uid_expunge`, `fetch`, `uid_fetch`, `store`, and `uid_store`.
* 💥 The `#extension` attribute on BODYSTRUCTURE structs no longer starts with `location`.  The location is now parsed directly and available from the `BodyStructure#location` attribute.  by @nevans in https://github.com/ruby/net-imap/pull/113

#### ✨ Added

##### Improved IMAP4rev1 protocol and extension support
* ✨ Add missing "location" BODYSTRUCTURE extension data by @nevans in https://github.com/ruby/net-imap/pull/113
* ✨ Cache server capabilities and add `#capable?(name)` by @nevans in https://github.com/ruby/net-imap/pull/156
* ✨ Add support for `ENABLE` (RFC 5161) by @arnt in https://github.com/ruby/net-imap/pull/98
* ✨ Parse UTF-8 encoded strings, for `UTF8=ACCEPT` and `IMAP4rev2` by @nevans in https://github.com/ruby/net-imap/pull/111
  * Minor bits for `UTF8=ACCEPT`  by @arnt in https://github.com/ruby/net-imap/pull/114
* ✨🔒 Add `SASL-IR` support by @nevans in https://github.com/ruby/net-imap/pull/90
  * 🐛 Fix empty `SASL-IR` to send "=" by @nevans in https://github.com/ruby/net-imap/pull/180

##### Improved SASL support
* 🔒 Add SASL OAUTHBEARER mechanism by @nevans in https://github.com/ruby/net-imap/pull/171
* 🔒 Add SASL ANONYMOUS mechanism by @nevans in https://github.com/ruby/net-imap/pull/169
* 🔒 Add SASL EXTERNAL mechanism by @nevans in https://github.com/ruby/net-imap/pull/170
* ✨ Make SASL.authenticator case insensitive by @nevans in https://github.com/ruby/net-imap/pull/167
  *  🐛 Fix authenticate using Symbol mechanism name by @nevans in https://github.com/ruby/net-imap/pull/186 
* ✨ Add attr_readers to SASL mechanisms by @nevans in https://github.com/ruby/net-imap/pull/176
* ✨ Allow keyword args on all SASL authenticators by @nevans in https://github.com/ruby/net-imap/pull/177
* 🔒 Verify SASL authentication has completed by @nevans in https://github.com/ruby/net-imap/pull/179
* 🔒 Add SASL SCRAM-SHA-* mechanisms by @nevans in https://github.com/ruby/net-imap/pull/172
* 🔒 SASL PLAIN: Raise ArgumentError for conflicts by @nevans in https://github.com/ruby/net-imap/pull/181
* ✨ Minor updates to SASL::Authenticators API by @nevans in https://github.com/ruby/net-imap/pull/184 

##### Improved `Net::IMAP` client API
* ✨ Add attr_readers for `host` and `port` by @nevans in https://github.com/ruby/net-imap/pull/92
* 🧵 New thread-safe API for `#responses` and add `#clear_responses` by @nevans in https://github.com/ruby/net-imap/pull/93
* ✨ Add greeting code data to `#responses` by @nevans in https://github.com/ruby/net-imap/pull/94
* ✨ Add `#capable?(name)`, `#auth_capable?(name)`, `#auth_mechanisms`, `#capabilities`, etc by @nevans in https://github.com/ruby/net-imap/pull/156
* 🔒 Add `#tls_verified?` by @nevans in https://github.com/ruby/net-imap/pull/91
* 🔒 Add `ssl_ctx` and `ssl_ctx_params` attr readers by @nevans in https://github.com/ruby/net-imap/pull/174
* ✨ Add `#logout!` to combine logout and disconnect  by @nevans in https://github.com/ruby/net-imap/pull/178

##### StringPrep profiles
* ✨ Add generic stringprep algorithm and the "trace" profile by @nevans in https://github.com/ruby/net-imap/pull/101
* ✨ Add Nameprep stringprep profile by @nevans in https://github.com/ruby/net-imap/pull/83

#### 🗑️ Deprecated
* 🗑️ Deprecated `#client_thread` by @nevans in https://github.com/ruby/net-imap/pull/93
* 🗑️🧵 Soft-deprecation of current `#responses` API by @nevans in https://github.com/ruby/net-imap/pull/93
  _The current API is not thread-safe._  It is documented as deprecated, but no warning message is logged yet.
* 🗑️ Deprecated `BodyTypeAttachment` and `BodyTypeExtension` structs @nevans in https://github.com/ruby/net-imap/pull/113
* 🗑️ Deprecate backward compatible parameters to `new` and `starttls` by @nevans in https://github.com/ruby/net-imap/pull/175
  `Net::IMAP.new` uses keyword parameters for its options now.
  Sending a port or an options hash as the second argument is documented as obsolete, but doesn't print warnings yet.
  _Any other positional parameters are deprecated and will print warnings._

#### 🐛 Fixed
* 🐛 Fix NAMESPACE parsing (and other ♻️ refactoring) by @nevans in https://github.com/ruby/net-imap/pull/112
* 🐛 Fix BODYSTRUCTURE parser bugs by @nevans in https://github.com/ruby/net-imap/pull/113
  * More strict about where NIL is not allowed, e.g: number, envelope, and body.  Ignoring these uncommon bugs made it difficult to workaround much more common server bugs elsewhere.
  * BodyTypeAttachment and BodyTypeExtension won't be returned any more.
  * Better workaround for multipart parts with... zero parts.
  * 🐛 Fix typo in uncommon BODYSTRUCTURE parsing code by @nevans in https://github.com/ruby/net-imap/pull/185
* 🧵 Synchronize `@responses` update in thread_internal by @nevans in https://github.com/ruby/net-imap/pull/116
* 🐛 Add missing lookahead_case_insensitive_string by @nevans in https://github.com/ruby/net-imap/pull/144
* Decode UTF-7 more strictly by @nobu in https://github.com/ruby/net-imap/pull/152
* Fix for Digest MD5 bad challenges by @nobu in https://github.com/ruby/net-imap/pull/160
* 🥅 Work around missing server responses by @nevans in https://github.com/ruby/net-imap/pull/192

#### ♻️ Changed
* 🔎 Improve parse error debugging by @nevans in https://github.com/ruby/net-imap/pull/105
* 🚚 Move the StringPrep module out of SASL by @nevans in https://github.com/ruby/net-imap/pull/100
* ✅ 📈 Move most parser tests to yaml, add more tests, and add parser benchmarks by @nevans in https://github.com/ruby/net-imap/pull/103
* 🧪 Add Regexp.linear_time? tests; ⚡✅ Update BEG_REGEXP to pass by @nevans in https://github.com/ruby/net-imap/pull/145
* ⚡✅  Update more regexps to run in linear time by @nevans in https://github.com/ruby/net-imap/pull/147
* 🧪 Add experimental new FakeServer for tests by @nevans in https://github.com/ruby/net-imap/pull/157
* ⏱️ Add Timeout to several existing SSL tests by @nevans in https://github.com/ruby/net-imap/pull/163
* ♻️ Use Net::IMAP::FakeServer::TestHelper by @nevans in https://github.com/ruby/net-imap/pull/164
* 🚚 Move and rename SASL authenticators by @nevans in https://github.com/ruby/net-imap/pull/165
* ♻️ Simplify lazy-loaded SASL::{Name}Authenticator registration by @nevans in https://github.com/ruby/net-imap/pull/168

#### 📚 Documentation
* 📚 Add "rake ghpages" for publishing rdoc by @nevans in https://github.com/ruby/net-imap/pull/102
* 📚 Auto-deploy GitHub Pages from an action by @nevans in https://github.com/ruby/net-imap/pull/135
* 📚 More rdoc updates, all related to capabilities by @nevans in https://github.com/ruby/net-imap/pull/159
* SASL doc updates by @nevans in https://github.com/ruby/net-imap/pull/166
* 📚 Update SASL docs and add attr_readers by @nevans in https://github.com/ruby/net-imap/pull/176
* 📚 Update examples with modern SASL mechanisms by @nevans in https://github.com/ruby/net-imap/pull/182


#### Miscellaneous
* Adds Ruby 3.2 to the CI matrix. by @petergoldstein in https://github.com/ruby/net-imap/pull/99
* Bump ruby/setup-ruby from 1.143.0 to 1.144.0 by @dependabot in https://github.com/ruby/net-imap/pull/138
* ✅ Add RFC3454 data, to support offline testing by @nevans in https://github.com/ruby/net-imap/pull/137
* ⬆️ Bump actions/deploy-pages from 1 to 2 by @dependabot in https://github.com/ruby/net-imap/pull/140
* ⬆️ Bump ruby/setup-ruby from 1.144.0 to 1.144.1 by @dependabot in https://github.com/ruby/net-imap/pull/139
* ⬆️ Bump ruby/setup-ruby from 1.144.1 to 1.144.2 by @dependabot in https://github.com/ruby/net-imap/pull/141
* Bump ruby/setup-ruby from 1.144.2 to 1.145.0 by @dependabot in https://github.com/ruby/net-imap/pull/142
* Bump ruby/setup-ruby from 1.145.0 to 1.146.0 by @dependabot in https://github.com/ruby/net-imap/pull/143
* Bump ruby/setup-ruby from 1.146.0 to 1.148.0 by @dependabot in https://github.com/ruby/net-imap/pull/148
* Bump ruby/setup-ruby from 1.148.0 to 1.149.0 by @dependabot in https://github.com/ruby/net-imap/pull/149
* Use test-unit-ruby-core from vendored code by @hsbt in https://github.com/ruby/net-imap/pull/151
* Bump ruby/setup-ruby from 1.149.0 to 1.150.0 by @dependabot in https://github.com/ruby/net-imap/pull/150
* Bump ruby/setup-ruby from 1.150.0 to 1.151.0 by @dependabot in https://github.com/ruby/net-imap/pull/153
* ⬆️ Bump ruby/setup-ruby from 1.151.0 to 1.152.0 by @dependabot in https://github.com/ruby/net-imap/pull/155
* Bump actions/upload-pages-artifact from 1 to 2 by @dependabot in https://github.com/ruby/net-imap/pull/158
* Bump actions/checkout from 3 to 4 by @dependabot in https://github.com/ruby/net-imap/pull/173

### New Contributors
* @petergoldstein made their first contribution in https://github.com/ruby/net-imap/pull/99
* @arnt made their first contribution in https://github.com/ruby/net-imap/pull/114

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.3.7...v0.4.0


## [v0.3.8](https://github.com/ruby/net-imap/tree/v0.3.8) (2025-02-07)

### What's Changed

#### 🔒 Security Fix
Mitigates CVE-2025-25186 (GHSA-7fc5-f82f-cx69): A malicious server can exhaust client memory by sending `APPENDUID` or `COPYUID` responses with very large `uid-set` ranges. `Net::IMAP::UIDPlusData` expands these ranges into arrays of integers.

##### Fix with minor API changes
For v0.3.8, this option is not available.  Upgrade to v0.4.19, v0.5.6, or higher to replace `UIDPlusData` with `AppendUIDData` and `CopyUIDData`.  These classes store their UIDs as `Net::IMAP::SequenceSet` objects (_not_ expanded into arrays of integers).

##### Mitigate with backward compatible API
This release mitigates the attack by crashing if a server tries to send a `uid-set` that represents more than 10,000 numbers.  This should be larger than almost all legitimate `COPYUID` or `APPENDUID` responses and would limit the array to only 80KB (on a 64 bit system).

For v0.3.8, this option is not configurable.  Upgrade to v0.4.19, v0.5.6, or higher to configure this limit.

##### Please Note: unhandled responses
If the client does not add response handlers to prune unhandled responses, a malicious server can still eventually exhaust all client memory, by repeatedly sending malicious responses.  However, `net-imap` has always retained unhandled responses, and it has always been necessary for long-lived connections to prune these responses.  This is not significantly different from connecting to a trusted server with a long-lived connection.  To limit the maximum number of retained responses, a simple handler might look something like the following:

  ```ruby
  limit = 1000
  imap.add_response_handler do |resp|
    name = resp.name
    code = resp.data.code&.name if resp.data.in?(Net::IMAP::ResponseText)
    # before 0.4.0:
    imap.responses[name].slice!(0...-limit)
    imap.responses[code].slice!(0...-limit)
    # since 0.4.0:
    imap.responses(name) { _1.slice!(0...-limit) }
    imap.responses(code) { _1.slice!(0...-limit) }
  end
  ```

#### Miscellaneous
* ✅ Renew test certificates for CI by @sorah in https://github.com/ruby/net-imap/pull/259

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.3.7...v0.3.8


## [v0.3.7](https://github.com/ruby/net-imap/tree/v0.3.7) (2023-07-26)

### What's Changed
* 🔒️ Backport: Fix for Digest MD5 bad challenges by @nobu in https://github.com/ruby/net-imap/pull/160
  * PR for backport is https://github.com/ruby/net-imap/pull/161

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.3.6...v0.3.7


## [v0.3.6](https://github.com/ruby/net-imap/tree/v0.3.6) (2023-06-12)

* 🐛 Fixes file permissions regression in [v0.3.5 release](https://github.com/ruby/net-imap/releases/tag/v0.3.5), reported by @aaronjensen in #154


## [v0.3.5](https://github.com/ruby/net-imap/tree/v0.3.5) (2023-06-12)

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.3.4...v0.3.5
    
* 📚 Fix #response documentation error, by @nevans in https://github.com/ruby/net-imap/commit/87ba74ebc054b9e8f3d8f26843ce5b974dbfe5ca
* ✅ Add RFC3454 data, to support offline testing, by @nevans in https://github.com/ruby/net-imap/pull/137
* Adds Ruby 3.2 to the CI matrix, by @petergoldstein in https://github.com/ruby/net-imap/pull/99
* Use reusing workflow, by @hsbt in https://github.com/ruby/net-imap/pull/151
* Decode UTF-7 more strictly, by @nobu in https://github.com/ruby/net-imap/pull/152
* ⬇️ Continue testing 0.3.x branch against ruby 2.6, by @nevans in https://github.com/ruby/net-imap/commit/115d19044e1c9ad1f834d0a4cecbc65d8faf9d00
* ✅ Fix decode utf-7 test for ruby 2.6, by @nevans in https://github.com/ruby/net-imap/commit/7a60c8f905deeae8e64588f174f33ef875dfba53
* 🐛 Fix XOAUTH2 authenticator for ruby 2.6, by @nevans in https://github.com/ruby/net-imap/commit/bd4faa03f87b64cab072e044834bfe5374fa4eb9


## [v0.3.4.1](https://github.com/ruby/net-imap/tree/v0.3.4.1) (2024-01-05)

### What's Changed
* Renew test certificates by @sorah in https://github.com/ruby/net-imap/pull/259

### New Contributors
* @sorah made their first contribution in https://github.com/ruby/net-imap/pull/259

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.3.4...v0.3.4.1


## [v0.3.4](https://github.com/ruby/net-imap/tree/v0.3.4) (2022-12-23)

### What's Changed
* Net::IMAP Client docs by @nevans in https://github.com/ruby/net-imap/pull/74


**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.3.3...v0.3.4


## [v0.3.3](https://github.com/ruby/net-imap/tree/v0.3.3) (2022-12-21)

### What's Changed
* Revert "Fixes "bundle exec rake", clash with test/unit" by @znz in https://github.com/ruby/net-imap/pull/88

### New Contributors
* @znz made their first contribution in https://github.com/ruby/net-imap/pull/88

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.3.2...v0.3.3


## [v0.3.2](https://github.com/ruby/net-imap/tree/v0.3.2) (2022-12-09)

### What's Changed
* Support `UIDPLUS` extension by @hoffi in https://github.com/ruby/net-imap/pull/65
* Fixes "bundle exec rake" clash with test/unit by @nevans in https://github.com/ruby/net-imap/pull/67
* Fix some UIDPLUS issues by @nevans in https://github.com/ruby/net-imap/pull/69
* Fixes date-time format, and adds decode_datetime by @nevans in https://github.com/ruby/net-imap/pull/66
* Add SASLprep. Code generated & tested with RFC3454 by @nevans in https://github.com/ruby/net-imap/pull/64
* Add the UNSELECT command by @nevans in https://github.com/ruby/net-imap/pull/72
* 🐛 Fix mailbox attrs by @nevans in https://github.com/ruby/net-imap/pull/73
* RFCs and references by @nevans in https://github.com/ruby/net-imap/pull/71
* Nodocs and remove warning by @nevans in https://github.com/ruby/net-imap/pull/70
* ResponseParser docs by @nevans in https://github.com/ruby/net-imap/pull/76
* Response Data docs by @nevans in https://github.com/ruby/net-imap/pull/75

### New Contributors
* @hoffi made their first contribution in https://github.com/ruby/net-imap/pull/65

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.3.1...v0.3.2


## [v0.3.1](https://github.com/ruby/net-imap/tree/v0.3.1) (2022-09-29)

### What's Changed
* Add XOAUTH2 authenticator by @ssunday in https://github.com/ruby/net-imap/pull/63

### New Contributors
* @ssunday made their first contribution in https://github.com/ruby/net-imap/pull/63

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.3.0...v0.3.1


## [v0.3.0](https://github.com/ruby/net-imap/tree/v0.3.0) (2022-09-28)

### What's Changed
* Added dependabot.yml for actions by @hsbt in https://github.com/ruby/net-imap/pull/59
* Bump actions/checkout from 2 to 3 by @dependabot in https://github.com/ruby/net-imap/pull/60
* Adding RFC licenses by @nevans in https://github.com/ruby/net-imap/pull/57
* Warn when using deprecated SASL mechanisms by @nevans in https://github.com/ruby/net-imap/pull/62

### New Contributors
* @dependabot made their first contribution in https://github.com/ruby/net-imap/pull/60

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.2.3...v0.3.0


## [v0.2.4](https://github.com/ruby/net-imap/tree/v0.2.4) (2024-01-05)

### What's Changed
* Renew test certificates by @sorah in https://github.com/ruby/net-imap/pull/259

### New Contributors
* @sorah made their first contribution in https://github.com/ruby/net-imap/pull/259

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.2.3...v0.2.4


## [v0.2.3](https://github.com/ruby/net-imap/tree/v0.2.3) (2022-01-06)

### What's Changed
* Update the required ruby version by @nobu in https://github.com/ruby/net-imap/pull/25
* Move NumValidator and Errors to other files by @nevans in https://github.com/ruby/net-imap/pull/27
* Remove max_flag_count. Ruby 2.2+ can GC symbols. by @nevans in https://github.com/ruby/net-imap/pull/26
* Add and document flags from RFC9051 by @nevans in https://github.com/ruby/net-imap/pull/28
* s/RubyVM::JIT/RubyVM::MJIT/g by @k0kubun in https://github.com/ruby/net-imap/pull/51
* Don't install bin directory by @voxik in https://github.com/ruby/net-imap/pull/53

### New Contributors
* @nobu made their first contribution in https://github.com/ruby/net-imap/pull/25
* @k0kubun made their first contribution in https://github.com/ruby/net-imap/pull/51
* @voxik made their first contribution in https://github.com/ruby/net-imap/pull/53

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.2.2...v0.2.3


## [v0.2.2](https://github.com/ruby/net-imap/tree/v0.2.2) (2021-07-07)

### What's Changed
* CI: Quote "3.0" in matrix by @olleolleolle in https://github.com/ruby/net-imap/pull/19
* Fix typo intentionaly -> intentionally [ci skip] by @kamipo in https://github.com/ruby/net-imap/pull/20
* Extract authenticators to their own files by @nevans in https://github.com/ruby/net-imap/pull/22

### New Contributors
* @olleolleolle made their first contribution in https://github.com/ruby/net-imap/pull/19
* @kamipo made their first contribution in https://github.com/ruby/net-imap/pull/20

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.2.1...v0.2.2


## [v0.2.1](https://github.com/ruby/net-imap/tree/v0.2.1) (2021-03-17)

### What's Changed
* Set timeout for IDLE responses by @shugo in https://github.com/ruby/net-imap/pull/15

### New Contributors
* @shugo made their first contribution in https://github.com/ruby/net-imap/pull/15

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.2.0...v0.2.1


## [v0.2.0](https://github.com/ruby/net-imap/tree/v0.2.0) (2021-03-10)

### What's Changed
* Add Net::IMAP::IgnoredResponse by @c-leroy in https://github.com/ruby/net-imap/pull/3
* Capability in response code by @nevans in https://github.com/ruby/net-imap/pull/6
* Extract public Net::IMAP.authenticator by @nevans in https://github.com/ruby/net-imap/pull/7
* Convert `send` to `__send__` by @nevans in https://github.com/ruby/net-imap/pull/13
* add BADCHARSET support by @nevans in https://github.com/ruby/net-imap/pull/9

### New Contributors
* @c-leroy made their first contribution in https://github.com/ruby/net-imap/pull/3

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.1.1...v0.2.0


## [v0.1.1](https://github.com/ruby/net-imap/tree/v0.1.1) (2020-12-22)

**Full Changelog**: https://github.com/ruby/net-imap/compare/v0.1.0...v0.1.1


## [v0.1.0](https://github.com/ruby/net-imap/tree/v0.1.0) (2020-03-26)

### What's Changed
* Use GitHub Actions instead of Travis CI by @hsbt in https://github.com/ruby/net-imap/pull/1


**Full Changelog**: https://github.com/ruby/net-imap/commits/v0.1.0

