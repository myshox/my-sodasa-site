// ============================================
// 蘇打石器 - 活動攻略系統完整代碼
// ============================================
// 使用說明：
// 1. 此文件包含完整的活動攻略功能代碼
// 2. 需要整合到 index.html 中的 <script type="text/babel"> 區塊
// 3. 支援從 Word 直接複製貼上（Ctrl+V）
// 4. 自動處理圖片（轉 Base64）
// ============================================

// ============================================
// 1. 活動攻略前台頁面（GuidesPage）
// ============================================

const GuidesPage = () => {
    const [guides, setGuides] = useState([]);
    const [loading, setLoading] = useState(true);
    const [selectedGuide, setSelectedGuide] = useState(null);
    const [category, setCategory] = useState('all');

    useEffect(() => {
        loadGuides();
    }, [category]);

    const loadGuides = async () => {
        try {
            let query = supabase
                .from('guides')
                .select('*')
                .eq('status', 'published')
                .order('is_pinned', { ascending: false })
                .order('publish_date', { ascending: false });

            if (category !== 'all') {
                query = query.eq('category', category);
            }

            const { data, error } = await query;

            if (error) throw error;
            setGuides(data || []);
        } catch (error) {
            console.error('載入攻略失敗:', error);
            showToast('載入攻略失敗', 'error');
        } finally {
            setLoading(false);
        }
    };

    const incrementViews = async (guideId) => {
        try {
            await supabase.rpc('increment_guide_views', { guide_id: guideId });
        } catch (error) {
            console.error('更新瀏覽次數失敗:', error);
        }
    };

    const handleGuideClick = (guide) => {
        setSelectedGuide(guide);
        incrementViews(guide.id);
    };

    if (selectedGuide) {
        return <GuideDetailView guide={selectedGuide} onBack={() => setSelectedGuide(null)} />;
    }

    return (
        <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            className="pt-32 md:pt-44 pb-28 md:pb-24 px-4 md:px-6 min-h-screen"
        >
            <PageHeader
                title="活動攻略"
                subtitle="最新活動資訊、遊戲技巧、精彩攻略一次掌握！"
                icon={BookOpen}
                color="text-gold-500"
            />

            {/* 分類選單 */}
            <div className="max-w-7xl mx-auto mb-8">
                <div className="flex flex-wrap gap-2 justify-center">
                    {[
                        { id: 'all', label: '全部', icon: '📚' },
                        { id: 'event', label: '活動', icon: '🎉' },
                        { id: 'pve', label: 'PVE', icon: '⚔️' },
                        { id: 'pvp', label: 'PVP', icon: '🛡️' },
                        { id: 'beginner', label: '新手', icon: '🌟' },
                        { id: 'general', label: '綜合', icon: '📖' }
                    ].map(cat => (
                        <button
                            key={cat.id}
                            onClick={() => setCategory(cat.id)}
                            className={`px-6 py-3 rounded-2xl font-bold transition-all duration-200 ${
                                category === cat.id
                                    ? 'bg-gold-500 text-white shadow-lg shadow-gold-200'
                                    : 'bg-white text-stone-600 hover:bg-stone-50 border-2 border-stone-200'
                            }`}
                        >
                            <span className="mr-2">{cat.icon}</span>
                            {cat.label}
                        </button>
                    ))}
                </div>
            </div>

            {loading ? (
                <LoadingSpinner message="載入攻略中..." />
            ) : guides.length === 0 ? (
                <div className="max-w-2xl mx-auto text-center py-20">
                    <div className="bg-white rounded-3xl p-12 border-2 border-stone-200">
                        <BookOpen size={48} className="mx-auto text-stone-300 mb-4" />
                        <p className="text-stone-500 font-bold text-lg">目前沒有攻略</p>
                        <p className="text-stone-400 text-sm mt-2">敬請期待精彩內容！</p>
                    </div>
                </div>
            ) : (
                <div className="max-w-7xl mx-auto">
                    <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
                        {guides.map(guide => (
                            <GuideCard key={guide.id} guide={guide} onClick={() => handleGuideClick(guide)} />
                        ))}
                    </div>
                </div>
            )}
        </motion.div>
    );
};

// ============================================
// 2. 攻略卡片組件（GuideCard）
// ============================================

const GuideCard = ({ guide, onClick }) => {
    const getCategoryInfo = (category) => {
        const categories = {
            event: { label: '活動', color: 'bg-fire-500', icon: '🎉' },
            pve: { label: 'PVE', color: 'bg-water-500', icon: '⚔️' },
            pvp: { label: 'PVP', color: 'bg-wind-500', icon: '🛡️' },
            beginner: { label: '新手', color: 'bg-gold-500', icon: '🌟' },
            general: { label: '綜合', color: 'bg-stone-500', icon: '📖' }
        };
        return categories[category] || categories.general;
    };

    const catInfo = getCategoryInfo(guide.category);

    return (
        <motion.div
            whileHover={{ y: -4 }}
            onClick={onClick}
            className="bg-white rounded-3xl overflow-hidden border-2 border-stone-200 cursor-pointer group shadow-sm hover:shadow-xl transition-all duration-300"
        >
            {/* 縮圖 */}
            {guide.thumbnail && (
                <div className="aspect-video bg-gradient-to-br from-stone-100 to-stone-200 overflow-hidden">
                    <img
                        src={guide.thumbnail}
                        alt={guide.title}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                </div>
            )}

            {/* 內容 */}
            <div className="p-6">
                {/* 置頂標籤 */}
                {guide.is_pinned && (
                    <div className="inline-flex items-center gap-1 bg-fire-500 text-white px-3 py-1 rounded-full text-xs font-bold mb-3">
                        <Star size={12} fill="white" />
                        置頂
                    </div>
                )}

                {/* 分類標籤 */}
                <div className={`inline-flex items-center gap-1 ${catInfo.color} text-white px-3 py-1 rounded-full text-xs font-bold mb-3 ml-2`}>
                    <span>{catInfo.icon}</span>
                    {catInfo.label}
                </div>

                {/* 標題 */}
                <h3 className="text-xl font-black text-stone-800 mb-3 line-clamp-2 group-hover:text-gold-600 transition-colors">
                    {guide.title}
                </h3>

                {/* 資訊 */}
                <div className="flex items-center justify-between text-sm text-stone-500">
                    <div className="flex items-center gap-4">
                        <span className="flex items-center gap-1">
                            <Eye size={14} />
                            {guide.views || 0}
                        </span>
                        <span className="flex items-center gap-1">
                            <Heart size={14} />
                            {guide.likes || 0}
                        </span>
                    </div>
                    <span className="text-xs">
                        {new Date(guide.publish_date || guide.created_at).toLocaleDateString('zh-TW')}
                    </span>
                </div>
            </div>
        </motion.div>
    );
};

// ============================================
// 3. 攻略詳細頁面（GuideDetailView）
// ============================================

const GuideDetailView = ({ guide, onBack }) => {
    return (
        <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="pt-32 md:pt-44 pb-28 md:pb-24 px-4 md:px-6 min-h-screen"
        >
            <div className="max-w-4xl mx-auto">
                {/* 返回按鈕 */}
                <button
                    onClick={onBack}
                    className="flex items-center gap-2 text-stone-600 hover:text-gold-600 font-bold mb-6 transition-colors"
                >
                    <ArrowLeft size={20} />
                    返回攻略列表
                </button>

                {/* 攻略內容 */}
                <div className="bg-white rounded-3xl overflow-hidden border-2 border-stone-200 shadow-xl">
                    {/* 標題區域 */}
                    <div className="bg-gradient-to-br from-gold-50 to-amber-50 p-8 md:p-12 border-b-2 border-gold-200">
                        <h1 className="text-3xl md:text-4xl font-black text-stone-800 mb-4">
                            {guide.title}
                        </h1>
                        <div className="flex items-center justify-between text-sm text-stone-600">
                            <div className="flex items-center gap-4">
                                <span className="flex items-center gap-1">
                                    <User size={14} />
                                    {guide.author_name || '管理員'}
                                </span>
                                <span className="flex items-center gap-1">
                                    <Calendar size={14} />
                                    {new Date(guide.publish_date || guide.created_at).toLocaleDateString('zh-TW')}
                                </span>
                                <span className="flex items-center gap-1">
                                    <Eye size={14} />
                                    {guide.views || 0} 瀏覽
                                </span>
                            </div>
                        </div>
                    </div>

                    {/* 攻略內容（HTML） */}
                    <div
                        className="prose prose-stone max-w-none p-8 md:p-12"
                        style={{
                            fontSize: '16px',
                            lineHeight: '1.8'
                        }}
                        dangerouslySetInnerHTML={{ __html: guide.content }}
                    />
                </div>
            </div>
        </motion.div>
    );
};

// ============================================
// 4. 管理員後台 - 攻略管理組件
// ============================================

const GuideManagementTab = () => {
    const [guides, setGuides] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showEditor, setShowEditor] = useState(false);
    const [editingGuide, setEditingGuide] = useState(null);
    const [currentUser, setCurrentUser] = useState(null);

    useEffect(() => {
        loadCurrentUser();
        loadGuides();
    }, []);

    const loadCurrentUser = async () => {
        const user = await authHelpers.getCurrentUser();
        setCurrentUser(user);
    };

    const loadGuides = async () => {
        try {
            const { data, error } = await supabase
                .from('guides')
                .select('*')
                .order('created_at', { ascending: false });

            if (error) throw error;
            setGuides(data || []);
        } catch (error) {
            console.error('載入攻略失敗:', error);
            showToast('載入攻略失敗', 'error');
        } finally {
            setLoading(false);
        }
    };

    const handleCreate = () => {
        setEditingGuide(null);
        setShowEditor(true);
    };

    const handleEdit = (guide) => {
        setEditingGuide(guide);
        setShowEditor(true);
    };

    const handleDelete = async (guideId) => {
        if (!confirm('確定要刪除這篇攻略嗎？')) return;

        try {
            const { error } = await supabase
                .from('guides')
                .delete()
                .eq('id', guideId);

            if (error) throw error;

            showToast('刪除成功', 'success');
            loadGuides();
        } catch (error) {
            console.error('刪除失敗:', error);
            showToast('刪除失敗', 'error');
        }
    };

    const handleEditorClose = () => {
        setShowEditor(false);
        setEditingGuide(null);
        loadGuides();
    };

    if (showEditor) {
        return <GuideEditor guide={editingGuide} currentUser={currentUser} onClose={handleEditorClose} />;
    }

    return (
        <div>
            <div className="flex items-center justify-between mb-6">
                <h2 className="text-2xl font-black text-stone-800">活動攻略管理</h2>
                <Button onClick={handleCreate} variant="gold" icon={Plus}>
                    新增攻略
                </Button>
            </div>

            {loading ? (
                <LoadingSpinner message="載入中..." />
            ) : guides.length === 0 ? (
                <div className="text-center py-20 bg-stone-50 rounded-2xl">
                    <BookOpen size={48} className="mx-auto text-stone-300 mb-4" />
                    <p className="text-stone-500 font-bold">目前沒有攻略</p>
                </div>
            ) : (
                <div className="space-y-4">
                    {guides.map(guide => (
                        <div key={guide.id} className="bg-white rounded-2xl p-6 border-2 border-stone-200">
                            <div className="flex items-start justify-between">
                                <div className="flex-1">
                                    <div className="flex items-center gap-2 mb-2">
                                        <h3 className="text-lg font-bold text-stone-800">{guide.title}</h3>
                                        {guide.is_pinned && (
                                            <span className="bg-fire-500 text-white px-2 py-1 rounded text-xs">置頂</span>
                                        )}
                                        <span className={`px-2 py-1 rounded text-xs font-bold ${
                                            guide.status === 'published' ? 'bg-wind-500 text-white' :
                                            guide.status === 'draft' ? 'bg-stone-300 text-stone-700' :
                                            'bg-stone-200 text-stone-600'
                                        }`}>
                                            {guide.status === 'published' ? '已發布' : guide.status === 'draft' ? '草稿' : '已封存'}
                                        </span>
                                    </div>
                                    <div className="flex items-center gap-4 text-sm text-stone-500">
                                        <span>瀏覽: {guide.views || 0}</span>
                                        <span>按讚: {guide.likes || 0}</span>
                                        <span>{new Date(guide.created_at).toLocaleString('zh-TW')}</span>
                                    </div>
                                </div>
                                <div className="flex gap-2">
                                    <button
                                        onClick={() => handleEdit(guide)}
                                        className="px-4 py-2 bg-water-500 text-white rounded-xl hover:bg-water-600 transition-colors"
                                    >
                                        編輯
                                    </button>
                                    <button
                                        onClick={() => handleDelete(guide.id)}
                                        className="px-4 py-2 bg-fire-500 text-white rounded-xl hover:bg-fire-600 transition-colors"
                                    >
                                        刪除
                                    </button>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
};

// ============================================
// 5. 富文本編輯器組件（GuideEditor）
// ============================================

const GuideEditor = ({ guide, currentUser, onClose }) => {
    const [title, setTitle] = useState(guide?.title || '');
    const [category, setCategory] = useState(guide?.category || 'general');
    const [status, setStatus] = useState(guide?.status || 'draft');
    const [isPinned, setIsPinned] = useState(guide?.is_pinned || false);
    const [saving, setSaving] = useState(false);
    const quillRef = useRef(null);
    const editorRef = useRef(null);

    useEffect(() => {
        // 初始化 Quill 編輯器
        if (!editorRef.current && quillRef.current) {
            const quill = new Quill(quillRef.current, {
                theme: 'snow',
                modules: {
                    toolbar: [
                        [{ 'header': [1, 2, 3, 4, 5, 6, false] }],
                        ['bold', 'italic', 'underline', 'strike'],
                        [{ 'color': [] }, { 'background': [] }],
                        [{ 'align': [] }],
                        [{ 'list': 'ordered'}, { 'list': 'bullet' }],
                        ['blockquote', 'code-block'],
                        ['link', 'image'],
                        ['clean']
                    ]
                },
                placeholder: '在此貼上您的內容...\n支援從 Word 直接複製貼上（Ctrl+V）'
            });

            // 載入現有內容
            if (guide?.content) {
                quill.root.innerHTML = guide.content;
            }

            // 自動處理圖片轉 Base64
            quill.getModule('toolbar').addHandler('image', () => {
                const input = document.createElement('input');
                input.setAttribute('type', 'file');
                input.setAttribute('accept', 'image/*');
                input.click();

                input.onchange = async () => {
                    const file = input.files[0];
                    if (file) {
                        const reader = new FileReader();
                        reader.onload = (e) => {
                            const range = quill.getSelection();
                            quill.insertEmbed(range.index, 'image', e.target.result);
                        };
                        reader.readAsDataURL(file);
                    }
                };
            });

            editorRef.current = quill;
        }
    }, [guide]);

    const handleSave = async () => {
        if (!title.trim()) {
            showToast('請輸入標題', 'warning');
            return;
        }

        const content = editorRef.current.root.innerHTML;
        if (!content.trim() || content === '<p><br></p>') {
            showToast('請輸入內容', 'warning');
            return;
        }

        setSaving(true);

        try {
            const guideData = {
                title: title.trim(),
                content,
                category,
                status,
                is_pinned: isPinned,
                author_id: currentUser.id,
                author_name: currentUser.email
            };

            if (guide) {
                // 更新
                const { error } = await supabase
                    .from('guides')
                    .update(guideData)
                    .eq('id', guide.id);

                if (error) throw error;
                showToast('更新成功', 'success');
            } else {
                // 新增
                const { error } = await supabase
                    .from('guides')
                    .insert([guideData]);

                if (error) throw error;
                showToast('新增成功', 'success');
            }

            onClose();
        } catch (error) {
            console.error('儲存失敗:', error);
            showToast('儲存失敗：' + error.message, 'error');
        } finally {
            setSaving(false);
        }
    };

    return (
        <div className="bg-white rounded-2xl p-6">
            <div className="flex items-center justify-between mb-6">
                <h2 className="text-2xl font-black text-stone-800">
                    {guide ? '編輯攻略' : '新增攻略'}
                </h2>
                <button
                    onClick={onClose}
                    className="text-stone-500 hover:text-stone-700"
                >
                    <X size={24} />
                </button>
            </div>

            <div className="space-y-6">
                {/* 標題 */}
                <div>
                    <label className="block text-stone-700 font-bold mb-2">標題 *</label>
                    <input
                        type="text"
                        value={title}
                        onChange={(e) => setTitle(e.target.value)}
                        placeholder="請輸入攻略標題"
                        className="w-full p-4 rounded-2xl border-2 border-stone-200 focus:border-gold-400 focus:ring-4 focus:ring-gold-100/50 focus:outline-none"
                    />
                </div>

                {/* 分類 */}
                <div>
                    <label className="block text-stone-700 font-bold mb-2">分類 *</label>
                    <select
                        value={category}
                        onChange={(e) => setCategory(e.target.value)}
                        className="w-full p-4 rounded-2xl border-2 border-stone-200 focus:border-gold-400 focus:ring-4 focus:ring-gold-100/50 focus:outline-none"
                    >
                        <option value="general">📖 綜合</option>
                        <option value="event">🎉 活動</option>
                        <option value="pve">⚔️ PVE</option>
                        <option value="pvp">🛡️ PVP</option>
                        <option value="beginner">🌟 新手</option>
                    </select>
                </div>

                {/* 內容編輯器 */}
                <div>
                    <label className="block text-stone-700 font-bold mb-2">內容 *</label>
                    <div className="bg-white border-2 border-stone-200 rounded-2xl overflow-hidden">
                        <div ref={quillRef} style={{ minHeight: '400px' }} />
                    </div>
                    <p className="text-xs text-stone-500 mt-2">
                        💡 支援從 Word 直接複製貼上（Ctrl+V），圖片會自動嵌入
                    </p>
                </div>

                {/* 選項 */}
                <div className="flex gap-6">
                    <label className="flex items-center gap-2 cursor-pointer">
                        <input
                            type="checkbox"
                            checked={isPinned}
                            onChange={(e) => setIsPinned(e.target.checked)}
                            className="w-5 h-5 text-gold-600 rounded focus:ring-2 focus:ring-gold-500"
                        />
                        <span className="text-stone-700 font-bold">置頂</span>
                    </label>

                    <label className="flex items-center gap-2">
                        <span className="text-stone-700 font-bold">狀態：</span>
                        <select
                            value={status}
                            onChange={(e) => setStatus(e.target.value)}
                            className="p-2 rounded-xl border-2 border-stone-200 focus:border-gold-400"
                        >
                            <option value="draft">草稿</option>
                            <option value="published">發布</option>
                            <option value="archived">封存</option>
                        </select>
                    </label>
                </div>

                {/* 按鈕 */}
                <div className="flex gap-4">
                    <Button
                        onClick={handleSave}
                        disabled={saving}
                        variant="gold"
                        className="flex-1"
                    >
                        {saving ? '儲存中...' : '儲存'}
                    </Button>
                    <Button
                        onClick={onClose}
                        variant="secondary"
                        className="flex-1"
                    >
                        取消
                    </Button>
                </div>
            </div>
        </div>
    );
};

// ============================================
// 代碼結束
// ============================================
