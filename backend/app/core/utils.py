import os
import random
import string
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

def generate_otp(length: int = 6) -> str:
    """Generate a random numeric OTP."""
    return "".join(random.choices(string.digits, k=length))

def send_otp_email(user_email: str, otp: str):
    """Send OTP email using SendGrid."""
    message = Mail(
        from_email='squatmate.team@gmail.com',
        to_emails=user_email,
        subject='SquatMate - Password Reset Code',
        html_content=f'''
        <div style="font-family: Arial, sans-serif; padding: 20px;">
            <h2>Password Reset</h2>
            <p>You requested a password reset for your SquatMate account.</p>
            <p>Your 6-digit code is: <strong style="font-size: 24px;">{otp}</strong></p>
            <p>This code will expire in 10 minutes.</p>
            <p>If you did not request this, please ignore this email.</p>
        </div>
        '''
    )
    try:
        sg = SendGridAPIClient(os.environ.get('SENDGRID_API_KEY'))
        response = sg.send(message)
        return True
    except Exception as e:
        print(f"Failed to send email: {e}")
        return False
