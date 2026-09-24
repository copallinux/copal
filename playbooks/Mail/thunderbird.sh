# playbook: thunderbird
# source:   apk
# origin:   catalogue
#
# program:  thunderbird
# label:    Thunderbird (full mail client)
# shelf:    Mail
# install:  thunderbird
# mode:     x
# gate:     !v6,!x32
# home:
# about:    Mozilla's mail client, with calendars and contacts built in. Copal can set up your
#           account from the installer's answers, so it opens on your inbox.

# Thunderbird: an account is nothing but prefs. profiles.ini names a
# profile, user.js inside it declares IMAP (993, TLS), SMTP (465, TLS)
# and a Local Folders store; the first start opens on the Inbox and
# asks for the password once. The numeric codes are Thunderbird's:
# socketType 3 = SSL/TLS, authMethod 3 = normal password. Only when
# answers.txt names a mail address; otherwise it keeps its wizard.
thunderbird_post() {
    [ -n "${PI_MAIL_ADDRESS:-}" ] || return 0
    _mname="${PI_MAIL_NAME:-${PI_GIT_NAME:-$PI_MAIL_ADDRESS}}"
    _imap="${PI_MAIL_IMAP:-imap.${PI_MAIL_ADDRESS#*@}}"
    _smtp="${PI_MAIL_SMTP:-smtp.${PI_MAIL_ADDRESS#*@}}"
    printf '[General]\nStartWithLastProfile=1\nVersion=2\n\n[Profile0]\nName=default\nIsRelative=1\nPath=copal.default\nDefault=1\n' > "$_t"
    seed_home_if_absent .thunderbird/profiles.ini "$_t"
    cat > "$_t" <<TB
user_pref("mail.accountmanager.accounts", "account1,account2");
user_pref("mail.accountmanager.defaultaccount", "account1");
user_pref("mail.accountmanager.localfoldersserver", "server2");
user_pref("mail.account.account1.identities", "id1");
user_pref("mail.account.account1.server", "server1");
user_pref("mail.account.account2.server", "server2");
user_pref("mail.server.server1.type", "imap");
user_pref("mail.server.server1.hostname", "$_imap");
user_pref("mail.server.server1.port", 993);
user_pref("mail.server.server1.socketType", 3);
user_pref("mail.server.server1.authMethod", 3);
user_pref("mail.server.server1.userName", "$PI_MAIL_ADDRESS");
user_pref("mail.server.server1.name", "$PI_MAIL_ADDRESS");
user_pref("mail.server.server2.type", "none");
user_pref("mail.server.server2.hostname", "Local Folders");
user_pref("mail.server.server2.name", "Local Folders");
user_pref("mail.identity.id1.fullName", "$_mname");
user_pref("mail.identity.id1.useremail", "$PI_MAIL_ADDRESS");
user_pref("mail.identity.id1.smtpServer", "smtp1");
user_pref("mail.smtpservers", "smtp1");
user_pref("mail.smtp.defaultserver", "smtp1");
user_pref("mail.smtpserver.smtp1.hostname", "$_smtp");
user_pref("mail.smtpserver.smtp1.port", 465);
user_pref("mail.smtpserver.smtp1.try_ssl", 3);
user_pref("mail.smtpserver.smtp1.authMethod", 3);
user_pref("mail.smtpserver.smtp1.username", "$PI_MAIL_ADDRESS");
user_pref("mail.shell.checkDefaultClient", false);
user_pref("app.donation.eoy.version.viewed", 99);
TB
    seed_home_if_absent .thunderbird/copal.default/user.js "$_t"
}
