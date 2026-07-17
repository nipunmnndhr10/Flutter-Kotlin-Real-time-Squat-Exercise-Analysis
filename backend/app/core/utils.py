import os
import random
import string
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def generate_otp(length: int = 6) -> str:
    """Generate a random numeric OTP."""
    return "".join(random.choices(string.digits, k=length))

def send_otp_email(user_email: str, otp: str):
    """Send OTP email using Gmail SMTP."""
    sender_email = "squatmate.team@gmail.com"
    app_password = os.environ.get('GMAIL_APP_PASSWORD')
    
    if not app_password:
        print("Failed to send email: GMAIL_APP_PASSWORD is not set in environment variables.")
        return False

    message = MIMEMultipart("alternative")
    message["Subject"] = "SquatMate - Password Reset Code"
    message["From"] = sender_email
    message["To"] = user_email

    html_content = f'''
    <div style="font-family: Arial, sans-serif; padding: 20px;">
        <h2>Password Reset</h2>
        <p>You requested a password reset for your SquatMate account.</p>
        <p>Your 6-digit code is: <strong style="font-size: 24px;">{otp}</strong></p>
        <p>This code will expire in 10 minutes.</p>
        <p>If you did not request this, please ignore this email.</p>
    </div>
    '''
    
    part = MIMEText(html_content, "html")
    message.attach(part)

    try:
        # Connect to Gmail's SMTP server using SSL
        server = smtplib.SMTP_SSL("smtp.gmail.com", 465)
        server.login(sender_email, app_password)
        server.sendmail(sender_email, user_email, message.as_string())
        server.quit()
        return True
    except Exception as e:
        print(f"Failed to send email: {e}")
        return False
