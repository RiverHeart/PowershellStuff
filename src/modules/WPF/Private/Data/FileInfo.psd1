@{
    Document = @(
        # General
        @{ Name = 'Text'; Extensions = 'txt'; Filter = '(*.txt)|*.txt'; Description =  'Plain text file' }
        @{ Name = 'Rich Text'; Extensions = 'rtf'; Filter = '(*.rtf)|*.rtf'; Description =  'Rich Text Format' }
        @{ Name = 'PDF'; Extensions = 'pdf'; Filter = '(*.pdf)|*.pdf'; Description =  'Portable Document Format' }
        @{ Name = 'CSV'; Extensions = 'csv'; Filter = '(*.csv)|*.csv'; Description =  'Comma-Separated Values' }
        @{ Name = 'E-Pub'; Extensions = 'epub'; Filter = '(*.epub)|*.epub'; Description =  'E-book format' }

        # Microsoft Office
        @{ Name = 'Excel'; Extensions = @('xls', 'xlsx', 'xlsm', 'xltx', 'xlsb'); Filter = '(*.xls;*.xlsx;*.xlsm;*.xltx;*.xlsb)|*.xls;*.xlsx;*.xlsm;*.xltx;*.xlsb'; Description =  'Microsoft Excel Spreadsheet' }
        @{ Name = 'Powerpoint'; Extensions = @('ppt', 'pptx', 'pptm', 'potx', 'potm'); Filter = '(*.ppt;*.pptx;*.pptm;*.potx;*.potm)|*.ppt;*.pptx;*.pptm;*.potx;*.potm'; Description =  'Microsoft PowerPoint Presentation' }
        @{ Name = 'Word Document'; Extensions = @('doc', 'docx', 'docm'); Filter = '(*.doc;*.docx;*.docm)|*.doc;*.docx;*.docm'; Description =  'Microsoft Word document' }

        # Open Document
        @{ Name = 'Open Text'; Extensions = @('odt', 'ott'); Filter = '(*.odt;*.ott)|*.odt;*.ott'; Description = 'Open Document Text' }
        @{ Name = 'Open Spreadsheet'; Extensions = @('ods', 'ots'); Filter = '(*.ods;*.ots)|*.ods;*.ots'; Description = 'Open Document Spreadsheet' }
        @{ Name = 'Open Presentation'; Extensions = @('odp', 'otp'); Filter = '(*.odp;*.otp)|*.odp;*.otp'; Description = 'Open Document Presentation' }
        @{ Name = 'Open Graphic'; Extensions = @('odg', 'otg'); Filter = '(*.odg;*.otg)|*.odg;*.otg'; Description = 'Open Document Graphic' }
    )

    Images = @(
        @{ Name = 'JPG'; Extensions = @('jpeg', 'jpg'); Filter = '(*.jpeg;*.jpg)|*.jpeg;*.jpg'; Description = 'JPEG Image' }
        @{ Name = 'PNG'; Extensions = 'png'; Filter = '(*.png)|*.png'; Description = 'Portable Network Graphics' }
        @{ Name = 'GIF'; Extensions = 'gif'; Filter = '(*.gif)|*.gif'; Description = 'Graphics Interchange Format' }
        @{ Name = 'Bitmap'; Extensions = 'bmp'; Filter = '(*.bmp)|*.bpm'; Description = 'Bitmap Image.' }
        @{ Name = 'SVG'; Extensions = 'svg'; Filter = '(*.svg)|*.svg'; Description = 'Scalable Vector Graphics' }
        @{ Name = 'Icon'; Extensions = 'ico'; Filter = '(*.ico)|*.ico'; Description = 'Windows Icon' }
        @{ Name = 'TIFF'; Extensions = @('tiff', 'tif'); Filter = '(*.tiff;*.tif)|*.tiff;*.tif'; Description = 'Tagged Image File Format' }
    )

    Audio = @(
        @{ Name = 'MP3'; Extensions = 'mp3'; Filter = '(*.mp3)|*.mp3'; Description =  'MPEG Audio Layer III' }
        @{ Name = 'WAV'; Extensions = 'wav'; Filter = '(*.wav)|*.wav'; Description =  'Waveform Audio File Format' }
        @{ Name = 'AAC'; Extensions = 'aac'; Filter = '(*.aac)|*.aac'; Description =  'Advanced Audio Coding' }
        @{ Name = 'M4A'; Extensions = 'm4a'; Filter = '(*.m4a)|*.m4a'; Description =  'MPEG-4 Audio' }
    )

    Video = @(
        @{ Name = 'mp4'; Extensions = 'mp4'; Filter = '(*.mp4)|*.mp4'; Description =  'MPEG-4 Video' }
        @{ Name = 'avi'; Extensions = 'avi'; Filter = '(*.avi)|*.avi'; Description =  'Audio Video Interleave' }
        @{ Name = 'mov'; Extensions = 'mov'; Filter = '(*.mov)|*.mov'; Description =  'QuickTime Movie' }
    )

    Executables = @(
        @{ Name = 'EXE'; Extensions = 'exe'; Filter = '(*.exe)|*.exe'; Description =  'Windows executable program' }
        @{ Name = 'DLL'; Extensions = 'dll'; Filter = '(*.dll)|*.dll'; Description =  'Dynamic Link Library' }
        @{ Name = 'Batch'; Extensions = 'bat'; Filter = '(*.bat)|*.bat'; Description =  'Batch script' }
    )

    Markup = @(
        @{ Name = 'HTML'; Extensions = @('html', 'htm', 'xhtml'); Filter = '(*.html;*.htm;*.htmx)|*.html;*.htm;*.htmx'; Description = 'HyperText Markup Language' }
        @{ Name = 'XML'; Extensions = 'xml'; Filter = '(*.xml)|*.xml'; Description = 'Extensible Markup Language' }
        @{ Name = 'Markdown'; Extensions = 'md'; Filter = '(*.md)|*.md'; Description = 'Markdown' }
        @{ Name = 'CSS'; Extensions = 'css'; Filter = '(*.css)|*.css'; Description = 'Cascading Style Sheets' }
    )

    Programming = @(
        # General
        @{ Name = 'Javascript'; Extensions = 'js'; Filter = '(*.js)|*.js'; Description = 'Javascript' }
        @{ Name = 'Ruby'; Extensions = 'rb'; Filter = '(*.rb)|*.rb'; Description = 'Ruby' }
        @{ Name = 'Python'; Extensions = 'py'; Filter = '(*.py)|*.py'; Description = 'Python' }
        @{ Name = 'PHP'; Extensions = 'php'; Filter = '(*.php)|*.php'; Description = 'PHP' }
        @{ Name = 'CSharp'; Extensions = 'cs'; Filter = '(*.cs)|*.cs'; Description = 'C#'}

        # Powershell
        @{ Name = 'Powershell (All)'; Extensions = @('ps1', 'psd1', 'psm1'); Filter = '(*.ps1;*.psd1;*.psm1)|*.psd1;*.psd1;*.psm1'; Description = 'Powershell Script' }
        @{ Name = 'Powershell'; Extensions = 'ps1'; Filter = '(*.ps1)|*.ps1'; Description = 'Powershell Script' }
        @{ Name = 'Powershell Data'; Extensions = 'psd1'; Filter = '(*.psd1)|*.psd1'; Description = 'Powershell Data File' }
        @{ Name = 'Powershell Module'; Extensions = 'psm1'; Filter = '(*.psdm1)|*.psm1'; Description = 'Powershell Module File' }
    )

    Archives = @(
        @{ Name = 'Zip'; Extensions = 'zip'; Filter = '(*.zip)|*.zip'; Description = 'Zip Archive' }
        @{ Name = 'RAR'; Extensions = 'rar'; Filter = '(*.rar)|*.rar'; Description = 'Roshal Archive' }
        @{ Name = '7-Zip'; Extensions = '7z'; Filter = '(*.7z)|*.7z'; Description = '7-Zip Archive' }
        @{ Name = 'TAR'; Extensions = 'tar'; Filter = '(*.tar)|*.tar'; Description = 'Tape Archive' }
        @{ Name = 'Tarball'; Extensions = @('tar.gz', 'tgz'); Filter = '(*.tar.gz;*.tgz)|*.tar.gz;*.tgz'; Description = 'Gnu Zipped Tape File' }
    )
}
