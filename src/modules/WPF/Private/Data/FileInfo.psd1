@{
    Categories = @{
        Document = @{ Display = 'Document'; Description = 'All Document File Types' }
        Image = @{ Display = 'Image'; Description = 'All Image File Types' }
        Audio = @{ Display = 'Audio'; Description = 'All Audio File Types' }
        Video = @{ Display = 'Video'; Description = 'All Video File Types' }
        Programming = @{ Display = 'Progamming'; Description = 'Programming Language Files' }
        Archive = @{ Display = 'Archive'; Description = 'All Archive File Types' }
        OpenDocument = @{ Display = 'OpenDocument'; Description = 'Files associated with Open/Libre Office' }
        Microsoft = @{ Display = 'Microsoft Office'; Description = 'Microsoft Office Files' }
        Powershell = @{ Display = 'Powershell'; Description = 'All Powershell File Types' }
    }
    FileInfo = @{
        All = @{ Display = "All Files"; Extensions = '*'; Filter = 'All Files (*.*)|*.*'; Description = 'All file types'; Categories = @() }

        #region Document
        #================

        #- Misc
        Text = @{ Display = 'Text'; Extensions = 'txt'; Filter = 'Text (*.txt)|*.txt'; Description = 'Plain text file'; Categories = 'Document' }
        RichText = @{ Display = 'RichText'; Extensions = 'rtf'; Filter = 'Rich Text (*.rtf)|*.rtf'; Description = 'Rich Text Format'; Categories = 'Document' }
        PDF = @{ Display = 'PDF'; Extensions = 'pdf'; Filter = 'PDF (*.pdf)|*.pdf'; Description = 'Portable Document Format'; Categories = 'Document' }
        CSV = @{ Display = 'CSV'; Extensions = 'csv'; Filter = 'CSV (*.csv)|*.csv'; Description = 'Comma-Separated Values'; Categories = 'Document' }
        EPub = @{ Display = 'EPub'; Extensions = 'epub'; Filter = 'EPub (*.epub)|*.epub'; Description = 'E-book format'; Categories = 'Document' }

        #- Microsoft Office
        Excel = @{ Display = 'Excel'; Extensions = @('xls', 'xlsx', 'xlsm', 'xltx', 'xlsb'); Filter = 'Excel (*.xls;*.xlsx;*.xlsm;*.xltx;*.xlsb)|*.xls;*.xlsx;*.xlsm;*.xltx;*.xlsb'; Description = 'Microsoft Excel Spreadsheet'; Categories = @('Document', 'MicrosoftOffice') }
        PowerPoint = @{ Display = 'PowerPoint'; Extensions = @('ppt', 'pptx', 'pptm', 'potx', 'potm'); Filter = 'PowerPoint (*.ppt;*.pptx;*.pptm;*.potx;*.potm)|*.ppt;*.pptx;*.pptm;*.potx;*.potm'; Description = 'Microsoft PowerPoint Presentation'; Categories = @('Document', 'MicrosoftOffice') }
        Word = @{ Display = 'Word'; Extensions = @('doc', 'docx', 'docm'); Filter = 'Word (*.doc;*.docx;*.docm)|*.doc;*.docx;*.docm'; Description = 'Microsoft Word document'; Categories = @('Document', 'MicrosoftOffice') }

        #- Open Document
        OpenText = @{ Display = 'Open Text'; Extensions = @('odt', 'ott'); Filter = 'Open Text (*.odt;*.ott)|*.odt;*.ott'; Description = 'Open Document Text'; Categories = @('Document', 'OpenDocument') }
        OpenSpreadsheet = @{ Display = 'Open Spreadsheet'; Extensions = @('ods', 'ots'); Filter = 'Open Spreadsheet (*.ods;*.ots)|*.ods;*.ots'; Description = 'Open Document Spreadsheet'; Categories = @('Document', 'OpenDocument') }
        OpenPresentation = @{ Display = 'Open Presentation'; Extensions = @('odp', 'otp'); Filter = 'Open Presentation (*.odp;*.otp)|*.odp;*.otp'; Description = 'Open Document Presentation'; Categories = @('Document', 'OpenDocument') }
        OpenGraphic = @{ Display = 'Open Graphic'; Extensions = @('odg', 'otg'); Filter = 'Open Graphic (*.odg;*.otg)|*.odg;*.otg'; Description = 'Open Document Graphic'; Categories = @('Document', 'OpenDocument') }

        #endregion Document

        #region Image
        #=============

        JPEG = @{ Display = 'JPEG'; Extensions = @('jpeg', 'jpg'); Filter = 'JPEG (*.jpeg;*.jpg)|*.jpeg;*.jpg'; Description = 'JPEG Image'; Categories = 'Image' }
        PNG = @{ Display = 'PNG'; Extensions = 'png'; Filter = 'PNG (*.png)|*.png'; Description = 'Portable Network Graphics'; Categories = 'Image' }
        GIF = @{ Display = 'GIF'; Extensions = 'gif'; Filter = 'GIF (*.gif)|*.gif'; Description = 'Graphics Interchange Format'; Categories = 'Image' }
        Bitmap = @{ Display = 'Bitmap'; Extensions = 'bmp'; Filter = 'Bitmap (*.bmp)|*.bpm'; Description = 'Bitmap Image.'; Categories = 'Image' }
        SVG = @{ Display = 'SVG'; Extensions = 'svg'; Filter = 'SVG (*.svg)|*.svg'; Description = 'Scalable Vector Graphics'; Categories = 'Image' }
        Icon = @{ Display = 'Icon'; Extensions = 'ico'; Filter = 'Icon (*.ico)|*.ico'; Description = 'Windows Icon'; Categories = 'Image' }
        TIFF = @{ Display = 'TIFF'; Extensions = @('tiff', 'tif'); Filter = 'TIFF (*.tiff;*.tif)|*.tiff;*.tif'; Description = 'Tagged Image File Format'; Categories = 'Image' }
        WebP = @{ Display = 'WebP'; Extensions = 'webp'; Filter = 'WebP (*.webp)|*.webp'; Description = 'Google Image Format'; Categories = 'Image' }

        #endregion

        #region Audio
        #=============

        MP3 = @{ Display = 'MP3'; Extensions = 'mp3'; Filter = 'MP3 (*.mp3)|*.mp3'; Description =  'MPEG Audio Layer III'; Categories = 'Audio' }
        WAV = @{ Display = 'WAV'; Extensions = 'wav'; Filter = 'WAV (*.wav)|*.wav'; Description =  'Waveform Audio File Format'; Categories = 'Audio' }
        AAC = @{ Display = 'AAC'; Extensions = 'aac'; Filter = 'AAC (*.aac)|*.aac'; Description =  'Advanced Audio Coding'; Categories = 'Audio' }
        M4A = @{ Display = 'M4A'; Extensions = 'm4a'; Filter = 'M4A (*.m4a)|*.m4a'; Description =  'MPEG-4 Audio'; Categories = 'Audio' }
        MIDI = @{ Display = 'MIDI'; Extensions = @('midi', 'mid', 'rmi'); Filter = 'MIDI (*.midi;*.mid;*.rmi)|*.midi;*.mid;*.rmi'; Description = 'MIDI File'; Categories = 'Audio' }
        FLAC = @{ Display = 'FLAC'; Extensions = 'flac'; Filter = 'FLAC (*.flac)|*.flac'; Description = 'FLAC Audio File'; Categories = 'Audio' }

        #endregion Audio

        #region Video
        #=============

        MP4 = @{ Display = 'mp4'; Extensions = 'mp4'; Filter = 'MP4 (*.mp4)|*.mp4'; Description = 'MPEG-4 Video'; Categories = 'Video' }
        AVI = @{ Display = 'avi'; Extensions = 'avi'; Filter = 'AVI (*.avi)|*.avi'; Description = 'Audio Video Interleave'; Categories = 'Video' }
        MOV = @{ Display = 'mov'; Extensions = 'mov'; Filter = 'MOV (*.mov)|*.mov'; Description = 'QuickTime Movie'; Categories = 'Video' }

        #endregion Video

        #region Executable
        #==================

        Exe = @{ Display = 'EXE'; Extensions = 'exe'; Filter = 'Exe (*.exe)|*.exe'; Description = 'Windows executable program'; Categories = 'Exe' }
        Dll = @{ Display = 'DLL'; Extensions = 'dll'; Filter = 'Dll (*.dll)|*.dll'; Description = 'Dynamic Link Library'; Categories = 'Dll' }
        Batch = @{ Display = 'Batch'; Extensions = 'bat'; Filter = 'Batch (*.bat)|*.bat'; Description = 'Batch script'; Categories = 'Executable' }

        #endregion Executable

        #region Markup
        #==============

        HTML =@{ Display = 'HTML'; Extensions = @('html', 'htm', 'xhtml'); Filter = 'HTML (*.html;*.htm;*.htmx)|*.html;*.htm;*.htmx'; Description = 'HyperText Markup Language'; Categories = 'Markup' }
        XML = @{ Display = 'XML'; Extensions = 'xml'; Filter = 'XML (*.xml)|*.xml'; Description = 'Extensible Markup Language'; Categories = 'Markup' }
        Markdown = @{ Display = 'Markdown'; Extensions = 'md'; Filter = 'Markdown (*.md)|*.md'; Description = 'Markdown'; Categories = 'Markup' }
        CSS = @{ Display = 'CSS'; Extensions = 'css'; Filter = 'CSS (*.css)|*.css'; Description = 'Cascading Style Sheets'; Categories = 'Markup' }
        PowershellType = @{ Display = 'Powershell Type'; Extensions = 'ps1xml'; Filter = 'Powershell Type (*.ps1xml)|*.ps1xml'; Description = 'Powershell Type File'; Categories = @('Markup', 'Powershell') }

        #endregion Markup

        #region Programming
        #===================

        #- Misc
        Javascript = @{ Display = 'Javascript'; Extensions = 'js'; Filter = 'Javascript (*.js)|*.js'; Description = 'Javascript'; Category = 'Programming' }
        Ruby =       @{ Display = 'Ruby'; Extensions = 'rb'; Filter = 'Ruby (*.rb)|*.rb'; Description = 'Ruby'; Category = 'Programming' }
        Python = @{ Display = 'Python';Extensions = 'py'; Filter = 'Python (*.py)|*.py'; Description = 'Python'; Categories = 'Programming' }
        PHP  = @{ Display = 'PHP'; Extensions = 'php'; Filter = 'PHP (*.php)|*.php'; Description = 'PHP'; Categories = 'Programming' }
        CSharp = @{ Display = 'CSharp'; Extensions = 'cs'; Filter = 'CSharp (*.cs)|*.cs'; Description = 'C#'; Categories = 'Programming' }

        #- Powershell
        PowershellAll = @{ Display = 'Powershell (All)'; Extensions = @('ps1', 'psd1', 'psm1'); Filter = 'Powershell Files (*.ps1;*.psd1;*.psm1)|*.psd1;*.psd1;*.psm1'; Description = 'All Powershell Files'; Categories = @('Programming', 'Powershell') }
        Powershell = @{ Display = 'Powershell'; Extensions = 'ps1'; Filter = 'Powershell (*.ps1)|*.ps1'; Description = 'Powershell Script'; Categories = @('Programming', 'Powershell') }
        PowershellData = @{ Display = 'Powershell Data'; Extensions = 'psd1'; Filter = 'Powershell Data (*.psd1)|*.psd1'; Description = 'Powershell Data File'; Categories = @('Programming', 'Powershell') }
        PowershellModule = @{ Display = 'Powershell Module'; Extensions = 'psm1'; Filter = 'Powershell Module (*.psdm1)|*.psm1'; Description = 'Powershell Module File'; Categories = @('Programming', 'Powershell') }
        #endregion Programming

        #region Archive
        #===============

        Zip = @{ Display = 'Zip'; Extensions = 'zip'; Filter = 'Zip (*.zip)|*.zip'; Description = 'Zip Archive'; Categories = 'Archive' }
        RAR = @{ Display = 'RAR'; Extensions = 'rar'; Filter = 'RAR (*.rar)|*.rar'; Description = 'Roshal Archive'; Categories = 'Archive' }
        '7ZIP' = @{ Display = '7-Zip'; Extensions = '7z'; Filter = '7-Zip (*.7z)|*.7z'; Description = '7-Zip Archive'; Categories = 'Archive' }
        TAR = @{ Display = 'TAR'; Extensions = 'tar'; Filter = 'TAR (*.tar)|*.tar'; Description = 'Tape Archive'; Categories = 'Archive' }
        Tarball = @{ Display = 'Tarball'; Extensions = @('tar.gz', 'tgz'); Filter = 'Tarball (*.tar.gz;*.tgz)|*.tar.gz;*.tgz'; Description = 'Gnu Zipped Tape File'; Categories = 'Archive' }

        #endregion Archive
    }
}
