module.exports = {
  branches: ['main'],
  plugins: [
    [
      '@semantic-release/commit-analyzer',
      {
        preset: 'conventionalcommits',
      },
    ],
    [
      '@semantic-release/release-notes-generator',
      {
        preset: 'conventionalcommits',
      },
    ],
    [
      '@semantic-release/changelog',
      {
        changelogFile: '../CHANGELOG.md',
      },
    ],
    [
      '@semantic-release/exec',
      {
        prepareCmd: `
          sed -i 's/version ".*"/version "\${nextRelease.version}"/g' ../fxmanifest.lua &&
          mkdir -p mri_Qfarm &&
          rsync -av --exclude='.release' --exclude='.git' --exclude='.github' --exclude='.claude' --exclude='.code-review-graph' --exclude='node_modules' --exclude='*.sh' --exclude='*.bat' --exclude='.gitignore' --exclude='.editorconfig' ../ mri_Qfarm/ &&
          zip -r ../mri_Qfarm.zip mri_Qfarm &&
          rm -rf mri_Qfarm &&
          echo "\${nextRelease.version}" > ../.VERSION &&
          echo "\${nextRelease.notes}" > ../.NOTES
        `,
      },
    ],
    [
      '@semantic-release/git',
      {
        assets: ['../CHANGELOG.md', '../fxmanifest.lua'],
        message: 'chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}',
      },
    ],
    [
      '@semantic-release/github',
      {
        assets: [
          { path: '../mri_Qfarm.zip', label: 'mri_Qfarm.zip' },
        ],
      },
    ],
  ],
};
