# playbook: claws-mail
# source:   apk
# origin:   catalogue
#
# program:  claws-mail
# label:    Claws Mail (GUI - Sylpheed lineage)
# shelf:    Mail
# install:  claws-mail
# mode:     x
# gate:     *
# home:
# about:    A fast, light mail client from the Sylpheed lineage. Copal can set up your account from
#           the installer's answers.

# Claws Mail skips its wizard when accountrc exists. protocol 3 is
# IMAP4, ssl_* 1 is TLS on connect, and the IMAP folder tree is
# declared in folderlist.xml or the account has nowhere to appear.
# Only when answers.txt names a mail address.
claws_mail_post() {
    [ -n "${PI_MAIL_ADDRESS:-}" ] || return 0
    _mname="${PI_MAIL_NAME:-${PI_GIT_NAME:-$PI_MAIL_ADDRESS}}"
    _imap="${PI_MAIL_IMAP:-imap.${PI_MAIL_ADDRESS#*@}}"
    _smtp="${PI_MAIL_SMTP:-smtp.${PI_MAIL_ADDRESS#*@}}"
    cat > "$_t" <<CLAWS
[Account: 1]
account_name=$PI_MAIL_ADDRESS
is_default=1
name=$_mname
address=$PI_MAIL_ADDRESS
protocol=3
receive_server=$_imap
smtp_server=$_smtp
user_id=$PI_MAIL_ADDRESS
password=
use_mail_command=0
ssl_imap=1
ssl_smtp=1
use_smtp_auth=1
smtp_user_id=$PI_MAIL_ADDRESS
set_imapport=1
imap_port=993
set_smtpport=1
smtp_port=465
imap_directory=
imap_subsonly=1
CLAWS
    seed_home_if_absent .claws-mail/accountrc "$_t"
    cat > "$_t" <<FOLD
<?xml version="1.0" encoding="UTF-8"?>
<folderlist>
  <folder type="imap" name="$PI_MAIL_ADDRESS" path="imapcache/$_imap/$PI_MAIL_ADDRESS" account_id="1" />
  <folder type="mh" name="Mail" path="Mail" />
</folderlist>
FOLD
    seed_home_if_absent .claws-mail/folderlist.xml "$_t"
}
