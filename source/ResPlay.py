import tkinter as tk
import tkinter.messagebox as msgbox
from tkinter import ttk
from tkinter import filedialog
from urllib import parse
import re
import threading
import webbrowser
import subprocess
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import os

# SRC: https://zhuanlan.zhihu.com/p/668890258 

class VideoPlayerApp:
    def __init__(self, width=500, height=300):
        self.w = width
        self.h = height
        self.title = '视频破解播放器plus——————2024-8-31-Made-By-中北锋哥'
        self.root = tk.Tk(className=self.title)
        self.url = tk.StringVar()
        self.v = tk.IntVar()
        self.v.set(1)
        self.port = 'http://jiexi.vipno.cn/?v='
        self.port2 = 'https://jx.77flv.cc/?url='
        self.port3 = 'https://jx.xmflv.com/?url='
        self.port4 = 'https://jx.2s0.cn/player/?url='
        self.port5 = 'https://jx.playerjy.com/?url='
        self.port6 = 'https://im1907.top/?jx='
        self.port7 = 'https://yparse.jn1.cc/index.php?url='
        self.port8 = 'https://jx.m3u8.tv/jiexi/?url='
        self.port9 = 'https://2.08bk.com/?url='
        self.port10 = 'https://rdfplayer.mrgaocloud.com/player/?url='
        self.ip = ''
        self.download_directory = ''
        self.cancel_flag = False  # Flag to indicate if the download should be canceled
        self.new_name = tk.StringVar()  # Variable to store the new name for the video

        self.setup_ui()

    def setup_ui(self):
        # Main Frames
        frame_1 = tk.Frame(self.root)
        frame_2 = tk.Frame(self.root)
        download_frame = tk.Frame(self.root)
        rename_frame = tk.Frame(self.root)

        frame_1.pack(pady=10)
        frame_2.pack(pady=10)
        download_frame.pack(pady=10)
        rename_frame.pack(pady=10)

        # Group Label
        group_label = tk.Label(frame_1, text='多通道解析选择：')
        group_label.grid(row=0, column=0, padx=10, pady=10)

        # Radiobutton
        tb1 = tk.Radiobutton(frame_1, text='通道 1', variable=self.v, value=1)
        tb1.grid(row=0, column=1, padx=5)

        tb2 = tk.Radiobutton(frame_1, text='通道 2', variable=self.v, value=2)
        tb2.grid(row=0, column=2, padx=5)

        tb3 = tk.Radiobutton(frame_1, text='通道 3', variable=self.v, value=3)
        tb3.grid(row=0, column=3, padx=5)

        tb4 = tk.Radiobutton(frame_1, text='通道 4', variable=self.v, value=4)
        tb4.grid(row=0, column=4, padx=5)

        tb5 = tk.Radiobutton(frame_1, text='通道 5', variable=self.v, value=5)
        tb5.grid(row=0, column=5, padx=5)

        tb6 = tk.Radiobutton(frame_1, text='通道 6', variable=self.v, value=6)
        tb6.grid(row=1, column=1, padx=5)

        tb7 = tk.Radiobutton(frame_1, text='通道 7', variable=self.v, value=7)
        tb7.grid(row=1, column=2, padx=5)

        tb8 = tk.Radiobutton(frame_1, text='通道 8', variable=self.v, value=8)
        tb8.grid(row=1, column=3, padx=5)

        tb9 = tk.Radiobutton(frame_1, text='通道 9', variable=self.v, value=9)
        tb9.grid(row=1, column=4, padx=5)

        tb10 = tk.Radiobutton(frame_1, text='通道 10', variable=self.v, value=10)
        tb10.grid(row=1, column=5, padx=5)

        # Input Label and Entry
        label = tk.Label(frame_2, text='请输入视频链接：')
        entry = tk.Entry(frame_2, textvariable=self.url, highlightcolor='Fuchsia', highlightthickness=1, width=40)
        label.grid(row=0, column=0, padx=(10, 0))
        entry.grid(row=0, column=1)

        # Play Button
        play = tk.Button(frame_2, text='播放', font=('楷体', 12), fg='Purple', width=8, height=1,
                         command=self.video_play)
        play.grid(row=0, column=2, padx=(10, 0))

        # Download Buttons and Progress Bar
        download_button = tk.Button(download_frame, text='下载(支持部分)', font=('楷体', 12), fg='Green',
                                    width=16,
                                    height=1,
                                    command=self.download_video)
        clear_button = tk.Button(download_frame, text='清空输入', font=('楷体', 12), fg='Red', width=11, height=1,
                                 command=self.clear_input)
        choose_dir_button = tk.Button(download_frame, text='选择下载目录', font=('楷体', 12), fg='Blue', width=13,
                                      height=1,
                                      command=self.choose_download_directory)
        cancel_button = tk.Button(download_frame, text='取消下载', font=('楷体', 12), fg='Red', width=11, height=1,
                                  command=self.cancel_download)

        download_button.grid(row=0, column=0, padx=(10, 0))
        clear_button.grid(row=0, column=1, padx=10)
        choose_dir_button.grid(row=0, column=2, padx=10)
        cancel_button.grid(row=0, column=3, padx=10)

        # Status Label and Progress Bar
        self.status_label = tk.Label(self.root, text='', fg='blue')
        self.status_label.pack(pady=0)
        self.progress_bar = ttk.Progressbar(self.root, mode='indeterminate')
        self.progress_bar.pack(fill='x', padx=10, pady=5)

        # Rename Label and Entry
        rename_label = tk.Label(rename_frame, text='请输入视频新名称：')
        rename_entry = tk.Entry(rename_frame, textvariable=self.new_name, highlightcolor='Fuchsia',
                                highlightthickness=1, width=51)
        rename_label.grid(row=0, column=0, padx=(10, 0))
        rename_entry.grid(row=0, column=1)

    def show_status_message(self, message):
        self.status_label.config(text=message)

    def clear_input(self):
        self.url.set('')  # Clear the input field

    def choose_download_directory(self):
        self.download_directory = filedialog.askdirectory()  # Open a file dialog to choose the download directory

    def cancel_download(self):
        self.cancel_flag = True

    def update_progress_bar(self, value):
        self.progress_bar["value"] = value

    def video_play(self):
        url = self.url.get()
        if re.match(r'^https?://\w.+$', url):
            self.ip = parse.quote_plus(url)
            if self.v.get() == 1:  # 根据选中的通道播放视频
                webbrowser.open(self.port + self.ip)
            elif self.v.get() == 2:
                webbrowser.open(self.port2 + self.ip)
            elif self.v.get() == 3:
                webbrowser.open(self.port3 + self.ip)
            elif self.v.get() == 4:
                webbrowser.open(self.port4 + self.ip)
            elif self.v.get() == 5:
                webbrowser.open(self.port5 + self.ip)
            elif self.v.get() == 6:
                webbrowser.open(self.port6 + self.ip)
            elif self.v.get() == 7:
                webbrowser.open(self.port7 + self.ip)
            elif self.v.get() == 8:
                webbrowser.open(self.port8 + self.ip)
            elif self.v.get() == 9:
                webbrowser.open(self.port9 + self.ip)
            elif self.v.get() == 10:
                webbrowser.open(self.port10 + self.ip)
        else:
            msgbox.showerror(title='错误', message='视频链接地址无效，请重新输入！')

    def download_video(self):
        url = self.url.get()
        if re.match(r'^https?://\w.+$', url):
            self.ip = parse.quote_plus(url)
            download_thread = threading.Thread(target=self.download_video_thread)
            download_thread.start()
            self.show_status_message('开始下载视频...')
        else:
            msgbox.showerror(title='错误', message='视频链接地址无效，请重新输入！')

    def download_video_thread(self):
        try:
            options = Options()
            options.add_argument('--headless')
            options.add_argument('--no-sandbox')
            options.add_argument('--disable-dev-shm-usage')
            options.add_argument("--window-size=1920,1080")
            options.add_argument(
                "user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.69 Safari/537.36'")

            driver = webdriver.Chrome(options=options)
            driver.get(self.port + self.ip)
            wait = WebDriverWait(driver, 10)
            video_element = wait.until(
                EC.presence_of_element_located((By.XPATH, '//div[@class="yzmplayer-video-wrap"]//video')))
            src_url = video_element.get_attribute("src")
            driver.quit()

            self.video_url = src_url
            video_url = self.video_url

            if not self.download_directory:
                msgbox.showerror(title='错误', message='请选择下载目录！')
                return

            self.update_progress_bar(0)
            self.cancel_flag = False

            # Start the download
            output_dir = self.download_directory
            subprocess.run(['you-get', '-o', output_dir, video_url])

            self.rename_video()
            self.show_status_message('视频下载已完成！')

        except Exception as e:
            print(e)
            self.show_status_message('下载视频出错，请重试。')

    def rename_video(self):
        if self.new_name.get():
            new_name = self.new_name.get() + '.mp4'
            if self.download_directory and os.path.exists(self.download_directory):
                files = os.listdir(self.download_directory)
                for file in files:
                    if file.endswith('.mp4'):
                        old_path = os.path.join(self.download_directory, file)
                        new_path = os.path.join(self.download_directory, new_name)
                        os.rename(old_path, new_path)
                        break

    def loop(self):
        self.root.resizable(True, True)
        self.root.mainloop()


if __name__ == "__main__":
    app = VideoPlayerApp()
    app.loop()