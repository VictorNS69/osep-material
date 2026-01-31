Automation of a phishing campaign using both an ICS calendar event and an HTML email body

_Most of the code was inspired by [FakeMeeting](https://github.com/ExAndroidDev/fakemeeting)._

## Requirements
The script expects these files in the same directory:
- `mail_data.txt` - Contains email/event details
- `msTeams-template.html` - HTML email MS Teams template
- `iCalendar_template.ics` - iCalendar template

## Setup your local SMTP and mail logs
- <https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-as-a-send-only-smtp-server-on-ubuntu-22-04>
- <https://www.electricmonk.nl/log/2015/03/06/keep-an-archive-of-all-mails-going-through-a-postfix-smtp-server/>
