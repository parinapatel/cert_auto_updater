# Cert_Auto_update
To Build :
```
docker build -t registry.aunalytics.com/devops/automated-certbot .
```

Envar needs to pass.

SECRET_ID=<SECERT ID IN AUNSIGHT>
CERT_SECRET_ID=<Secret ID in Aunsight where Cert is stored>
DOMAIN_NAME=<Domain for which Cert needs to be genrated.>
  
  
# To Validate Cert Validity

```bash
check_ssl_validity.sh [-h] [-c] [-d DAYS] [-f FILENAME] | [-w WEBSITE] | [-s SITELIST]

Retrieve the expiration date(s) on SSL certificate(s) using OpenSSL.

Usage:
    -h  Help

    -c  Color output

    -d  Amount of days to show warnings (default is 30 days)
        Example: -d 15

    -f  SSL date from FILENAME
        Example: -f /home/user/example.pem

    -w  SSL date from SITE(:PORT) (Port defaults to 443)
        Example: -w www.example.com

    -s  SSL date(s) from SITELIST
        Example:      -s ./websites.txt
        List format:  sub.domain.tld:993 (one per line - port optional)

Example:
    $ check_ssl_validity.sh -c -d 14 -s ./websites.txt

    WARNS (in color) if within 14 days of expiring on each entry in the file list.
```

SiteList Example 

```
www.google.com
www.yahoo.com
```
