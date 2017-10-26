# Koha-translations
Koha-Suomi translation files are kept here under lock and key. Changes are automatically pushed to testing/production.

For how the translation process should work, see:
https://tiketti.koha-suomi.fi:83/issues/2478


Some manual setup is required:

-You must authorize the primary translations CI test server for write access to this repo.
 This is done via the GitHub -> repo -> Settings -> Deploy keys

-You must configure a GitHub post-commit -hook to send notifications to unelma.pohjoiskarjala.net
 This is done via the Github -> repo -> Settings -> Webhooks
   -Payload URL: https://unelma.pohjoiskarjala.net/job/Koha-translations%20pipeline/build?token=SECRETTOKEN
   -Just the push event
   -Active = true

-Configure a Build Pipeline in Jenkins to receive the post-commit hook
 This is under version control in
 https://github.com/KohaSuomi/Koha-Ansible-Pipeline/tree/master/Jenkins-Pipeline/Koha-translations



Note: Source code changes can be updated to the translations repo only when a change has been made to this
translations-repo. Otherwise this repo's version history would be cluttered by automatic version upgrade
changes, because the Koha's source code changes a lot.
