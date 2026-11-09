## Description

<!-- Please include a summary of the change and which issue is fixed here. -->

## Checklist
- [ ] Make sure that you are listed in the AUTHORS file
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] New and existing unit tests pass locally with my changes
- [ ] If this needs a change in OpenMS (OpenMS/OpenMS), the PR there is linked

No need to edit the CHANGELOG file: the maintainers update it for a release.

### How can I get additional information on failed tests during CI
<details>
  <summary>Click to expand</summary>
If your PR is failing you can check out

- The details of the action statuses at the end of the PR or the "Checks" tab.
- The log of the failed job: `ctest --output-on-failure` prints the output of each failed test.

</details>

---
:warning: Note: Once you opened a PR try to minimize the number of *pushes* to it as every push will trigger CI (automated builds and test) and is rather heavy on our infrastructure (e.g., if several pushes per day are performed).
